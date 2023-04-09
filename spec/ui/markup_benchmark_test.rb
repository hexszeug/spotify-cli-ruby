# frozen_string_literal: true

require 'benchmark'
require 'curses'
require './lib/ui/markup'

Curses.init_screen
UI::Markup::Colors.start
Curses.close_screen
markup = UI::Markup.new('$*Formatted$* $rlong $@#163264text$0c ' * 10_000)

Benchmark.bm(15) do |bm|
  bm.report('lines') { markup.lines }
  bm.report('chomp') { markup.chomp }
  bm.report('strip') { markup.strip }
  bm.report('slice begin') { markup.slice(..50) }
  bm.report('slice center') { markup.slice(300..-300) }
  bm.report('slice end') { markup.slice(-50..) }
  bm.report('old scale 10k') do
    UI::Markup::Utils.old_scale(markup.markup, 10_000)
  end
  bm.report('old scale 1k') do
    UI::Markup::Utils.old_scale(markup.markup, 1000)
  end
  bm.report('old scale 100') { UI::Markup::Utils.old_scale(markup.markup, 100) }
  bm.report('scale 10k') { markup.scale(10_000) }
  bm.report('scale 1k') { markup.scale(1000) }
  bm.report('scale 100') { markup.scale(100) }
end
