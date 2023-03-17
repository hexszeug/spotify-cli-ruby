# frozen_string_literal: true

module UI
  class Input
    # @todo suggestions (TAB Arrow Up/Down, maybe PPAGE, NPAGE)
    # @todo insert-mode
    include Curses::Key

    def initialize
      @win = Curses::Window.new(0, 0, 0, 0)
      @win.timeout = 0
      @win.keypad(true)
      @win.scrollok(true)

      @string = String.new
      @cursor = 0
      @display_cursor = 0
      @history = [@string]
      @history_pointer = 0
      @changed = false
      @display_size = 0
    end

    def resize
      UI.resize_window(@win, 1, -2, -1, -2)
      size = @win.maxx - 1
      return if size == @display_size

      @changed = true
      prev_size = @display_size
      @display_size = size
      if @display_cursor >= @display_size
        @display_cursor = @display_size - 1
      elsif @cursor == @string.length && @display_cursor == prev_size - 1
        @display_cursor = [@cursor, @display_size - 1].min
      end
    end

    def touch
      @changed = true
    end

    def refresh
      return unless @changed

      @changed = false
      s = @cursor - @display_cursor
      e = s + @display_size
      @win.deleteln
      @win.setpos 0, 0
      @win.addstr @string[s...e]
      @win.setpos 0, @display_cursor

      @win.refresh
    end

    def read
      ch = @win.get_char
      return unless ch

      case ch
      when RESIZE
        UI.resize
      when BACKSPACE
        return unless @cursor.positive?

        @string.slice! @cursor - 1
        move_cursor @cursor - 1
      when "\b" # CTRL+BACKSPACE (for some random reason)
        return unless @cursor.positive?

        c = @cursor - 2
        i = @string.rindex(/ [^ ]/, [c, 0].max)
        i = i ? i + 1 : 0
        @string.slice! i...@cursor
        move_cursor i
      when DC
        return if @string.empty?

        @string.slice! @cursor
      when 0x208 # CTRL+DC
        return if @string.empty?

        i = @string.index(/ [^ ]/, @cursor)
        @string.slice! @cursor..i
      when LEFT
        return unless @cursor.positive?

        move_cursor @cursor - 1
      when 0x222 # CTRL+LEFT
        return unless @cursor.positive?

        c = @cursor - 2
        i = @string.rindex(/ [^ ]/, [c, 0].max)
        move_cursor i ? i + 1 : 0
      when HOME
        return unless @cursor.positive?

        move_cursor 0
      when RIGHT
        return unless @cursor < @string.length

        move_cursor @cursor + 1
      when 0x231 # CTRL+RIGHT
        return unless @cursor < @string.length

        i = @string.index(/ [^ ]/, @cursor)
        move_cursor i ? i + 1 : @string.length
      when Curses::KEY_END
        return unless @cursor < @string.length

        move_cursor @string.length
      when UP
        return unless @history_pointer.positive?

        @history_pointer -= 1
        @string = @history[@history_pointer].dup
        move_cursor @string.length
      when DOWN
        return unless @history_pointer < @history.length - 1

        @history_pointer += 1
        @string = @history[@history_pointer]
        @string = @string.dup if @history_pointer < @history.length - 1
        move_cursor @string.length
      when ENTER, "\n", "\r"
        return if @string.empty?

        UI.on_return @string.dup
        if @history[-2] == @string
          @history[-1] = @string
        else
          @history[-1] = @string.dup
          @history.push @string
        end
        @string.clear
        @history_pointer = @history.length - 1
        move_cursor 0
      when 0x237 # CTRL+UP
        Output.scroll(-1)
      when PPAGE
        Output.scroll { |h| 1 - h }
      when 0x20e # CTRL+DOWN
        Output.scroll 1
      when NPAGE
        Output.scroll { |h| h - 1 }
      else
        return unless ch.is_a?(String) && ch =~ /^[[:print:]]$/

        @string.insert @cursor, ch
        move_cursor @cursor + 1
      end
      @changed = true
      nil
    end

    private

    def move_cursor(cursor)
      return if !cursor.between?(0, @string.length) || cursor == @cursor

      d = (@cursor - cursor).abs
      if @cursor > cursor
        @display_cursor -= d
        unless @display_cursor.positive?
          @display_cursor = [cursor, @display_size - 1].min
        end
      else
        @display_cursor = [@display_cursor + d, @display_size - 1].min
      end
      @cursor = cursor
    end
  end
end
