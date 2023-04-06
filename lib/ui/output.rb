# frozen_string_literal: true

module UI
  class Output
    def initialize
      @win = Curses::Window.new(0, 0, 0, 0)
      @win.timeout = -1
      @win.keypad(true)
      @win.scrollok(true)

      @screen_messages = []
      @display = []
      @first_displayed_message = -1
      @first_undisplayed_message = 0
      @scroll = 0
      @old_scroll = 0
      @height = 0
      @width = 0
      @changed_size = false
    end

    def resize
      UI.resize_window(@win, 1, 1, -1, -4)
      @changed_size = true
      @height = @win.maxy
      @width = @win.maxx - 1
    end

    def refresh(force: false)
      # @todo add scroll bar
      force = true if @changed_size
      first_change = @screen_messages.find_index(&:changed?)
      first_change = 0 if force
      if first_change && @scroll != @old_scroll
        # special case: scrolled and updated message in same tick
        @first_undisplayed_message = @screen_messages.length
      end
      if first_change && first_change <= @first_undisplayed_message
        generate_least_as_possible(first_change, force)
        print_display
      elsif @scroll != @old_scroll
        amount = @old_scroll - @scroll
        if amount.negative?
          generate_least_as_possible(@first_undisplayed_message, true)
          amount = @old_scroll - @scroll
          return if amount.zero?
        end

        @win.scrl(amount)
        if amount.positive?
          print_display(@height - amount, 0)
        else
          print_display(0, @height + amount)
        end
      else
        return
      end

      @changed_size = false
      @old_scroll = @scroll

      @win.noutrefresh
      UI.input.touch
    end

    def print(screen_message)
      return unless screen_message.is_a?(ScreenMessage)

      @screen_messages.unshift(screen_message)
      @display.unshift([]) # @todo this is kind of hacky, make it more reliable
    end

    def scroll(amount = 0)
      amount = yield @height if block_given?
      return if amount.zero?

      @scroll = [(@scroll - amount), 0].max
    end

    private

    def generate_least_as_possible(offset, force)
      generated_lines = @display[...offset].map(&:length).sum
      overscrolled =
        @screen_messages[offset..].each.with_index(offset) do |message, i|
          @display[i] = message.lines(@width) if force || message.changed?
          generated_lines += @display[i].length
          break false if generated_lines >= @scroll + @height
        end
      return unless overscrolled

      max_scroll = [@display.map(&:length).sum - @height, 0].max
      @scroll = max_scroll if @scroll > max_scroll
    end

    def print_display(top_padding = 0, bottom_padding = 0)
      # fetch messages
      lines_before = 0
      lines_in = 0
      @first_displayed_message = 0
      @first_undisplayed_message = 1 + (
        @display.find_index do |lines|
          if lines_before + lines_in + lines.length < @scroll
            lines_before += lines.length
            @first_displayed_message += 1
          else
            lines_in += lines.length
          end
          lines_before + lines_in >= @scroll + @height
        end || (@display.length - 1)
      )
      messages =
        @display[@first_displayed_message...@first_undisplayed_message].reverse

      # clear screen
      (top_padding...(@height - bottom_padding)).each do |y|
        @win.setpos(y, 0)
        @win.clrtoeol
      end

      # write to screen
      bottom_margin = @scroll - lines_before
      top_margin = lines_in - bottom_margin - @height
      y = -top_margin
      messages.each do |lines|
        start = [top_padding - y, 0].max
        stop = @height - bottom_padding - y
        if start < lines.length && stop.positive?
          @win.setpos(y + start, 0)
          Markup.print_lines(@win, lines, start...stop)
        end
        y += lines.length
      end
    end
  end
end
