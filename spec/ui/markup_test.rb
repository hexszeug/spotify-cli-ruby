# frozen_string_literal: true

require './lib/ui/markup'

require 'curses'

puts 'hello'['dud']

Curses.init_screen
UI::Markup::Colors.start

markup = UI::Markup.new(<<~TEXT)
  Hello World
  $rRed text
  $@gBackground color$0C
  $#163264Custom color$0C
  $*Bold text
  $0AAll Reset
TEXT

markup.print_to(Curses.stdscr)
markup.lines.each { |line| line[5, 10].print_to(Curses.stdscr) }

Curses.getch

Curses.close_screen
