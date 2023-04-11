# frozen_string_literal: true

module UI
  class Output
    def initialize
      @win = Curses::Window.new(0, 0, 0, 0)
      @win.timeout = -1
      @win.keypad(true)
      @win.scrollok(true)

      @screen_messages = []
      @definetly_hidden = -1
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
      # @todo some small performance issues when scrolling very high up
      newest_change = @screen_messages.rindex(&:changed?) || -1
      content_changed = newest_change > @definetly_hidden
      scrolled = @scroll != @old_scroll
      return unless force || @changed_size || content_changed || scrolled

      @definetly_hidden = @screen_messages.length - 1
      lines = []
      @screen_messages.reverse_each do |screen_message|
        @definetly_hidden -= 1
        lines.unshift(*screen_message.generate(@width).lines)
        break if lines.length >= @scroll + @height
      end
      if lines.length < @scroll + @height # scrolled too far
        @scroll = [lines.length - @height, 0].max
      end

      lines.pop(@scroll)
      if lines.length > @height
        lines.shift(lines.length - @height)
      elsif lines.length < @height
        (@height - lines.length).times { lines.unshift(nil) }
      end

      @height.times do |y|
        @win.setpos(y, 0)
        @win.clrtoeol
        lines[y]&.rstrip&.print_to(@win)
      end

      @changed_size = false
      @old_scroll = @scroll

      @win.noutrefresh
      UI.input.touch
    end

    def print(screen_message)
      unless screen_message.is_a?(ScreenMessage)
        raise TypeError,
              "no implicit conversion of #{screen_message.class} into #{ScreenMessage}"
      end

      @screen_messages.push(screen_message)
    end

    def scroll(amount = 0, absolute: false)
      amount = yield @height if block_given?
      pos = absolute ? amount : @scroll - amount
      @scroll = [pos, 0].max
    end
  end
end
