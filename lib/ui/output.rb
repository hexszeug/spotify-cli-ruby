# frozen_string_literal: true

module UI
  class Output
    def initialize
      @win = Curses::Window.new(0, 0, 0, 0)
      @win.timeout = -1
      @win.keypad(true)
      @win.scrollok(true)

      @generators = []
      @old_generators_length = 0
      @display = []
      @scroll = 0
      @old_scroll = 0
      @height = 0
      @width = 0
      @changed_size = false
    end

    def resize
      UI.resize_window(@win, 1, 1, -1, -4)
      h = @win.maxy
      w = @win.maxx - 1
      return if @height == h && @width == w

      @changed_size = true
      @height = h
      @width = w
    end

    def refresh(force: false)
      # @todo add scroll bar
      changed_output = @generators.length != @old_generators_length
      changed_size = @changed_size
      scrolled = @scroll != @old_scroll
      return unless changed_output || changed_size || scrolled || force

      if changed_size || force
        @display = []
        @generators.each do |gen|
          lines = gen.call
          next unless lines

          @display += lines
        end
        @scroll = @scroll.clamp(0, [@display.length - @height, 0].max)
        @win.clear
        @win.setpos [@height - @display.length, 0].max, 0
        s = [@display.length - @height - @scroll, 0].max
        e = @display.length - @scroll - 1
        @win.addstr @display[s..e] * "\n"
      elsif changed_output
        @scroll = 0
        new_lines = 0
        @generators[@old_generators_length..nil].each do |gen|
          lines = gen.call
          @display += lines
          new_lines += lines.length
        end
        @win.scrl new_lines
        @win.setpos [@height - new_lines, 0].max, 0
        s = @display.length - [new_lines, @height].min
        @win.addstr @display[s..nil] * "\n"
      elsif scrolled
        amount = @old_scroll - @scroll
        s = [@display.length - @height - @scroll, 0].max
        e = @display.length - @scroll - 1
        c = 0
        if amount.positive?
          s = [e - amount + 1, s].max
          c = @height - e + s - 1
        else
          e = [s - amount - 1, e].min
        end
        @win.scrl amount
        @win.setpos c, 0
        @win.addstr @display[s..e] * "\n"
      end
      @old_generators_length = @generators.length
      @changed_size = false
      @old_scroll = @scroll

      @win.noutrefresh
      UI.input.touch
    end

    def print
      return unless block_given?

      @generators.push(
        proc do
          lines = (yield @width).dup
          next if lines.nil?

          lines = [lines] if lines.is_a?(String)
          return unless lines.is_a?(Array)

          lines = lines.join("\n").split("\n")
          lines.each.with_index do |line, i|
            next unless line.length > @width

            e = line.rindex(/\s/, @width)
            e ||= @width
            s = line.index(/\S/, e) - e
            new_line = line.slice!(e...line.length)
            next unless s && new_line

            new_line.slice!(0...s)
            next if new_line.empty?

            lines.insert(i + 1, new_line)
          end
          lines
        end
      )
    end

    def scroll(amount = 0)
      amount = yield @height if block_given?
      return if amount.zero?

      @scroll = (@scroll - amount).clamp(0, [@display.length - @height, 0].max)
    end
  end
end
