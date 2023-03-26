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
      h = @win.maxy
      w = @win.maxx - 1
      return if @height == h && @width == w

      @changed_size = true
      @height = h
      @width = w
    end

    def refresh(force: false)
      # @todo add scroll bar
      # @todo stop scrolling when reaching end of generators
      force = true if @changed_size
      first_change = @screen_messages.find_index(&:changed?)
      first_change = 0 if force
      if first_change && @scroll != @old_scroll
        # special case: scrolled and updated message in same tick
        @first_undisplayed_message = @screen_messages.length
      end
      if first_change && first_change <= @first_undisplayed_message
        # generate
        generate_least_as_possible(first_change, force)

        # print
        messages =
          @display[@first_displayed_message...@first_undisplayed_message].reverse
        lines_before = @display[...@first_displayed_message].map(&:length).sum
        lines_in = messages.map(&:length).sum
        bottom_cutoff = @scroll - lines_before
        top_cutoff = lines_in - @height - bottom_cutoff
        @win.setpos([-top_cutoff, 0].max, 0)
        messages.each_with_index do |lines, i|
          start = [top_cutoff, 0].max if i.zero?
          stop = -(bottom_cutoff + 1) if i == messages.length - 1
          Markup.print_lines(@win, lines, start..stop)
        end
      elsif @scroll != @old_scroll
        # @todo scroll display
        # generate
        if @scroll > @old_scroll
          generate_least_as_possible(@first_undisplayed_message, true)
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
      @display.unshift([])
    end

    def scroll(amount = 0)
      amount = yield @height if block_given?
      return if amount.zero?

      @scroll = [(@scroll - amount), 0].max
    end

    private

    def generate_least_as_possible(offset, force)
      generated_lines = @display[...offset].map(&:length).sum
      @first_displayed_message = offset
      @first_undisplayed_message = offset
      @screen_messages[offset..]
        .each
        .with_index(offset) do |message, i|
        @display[i] = message.lines(@width) if force || message.changed?
        generated_lines += @display[i].length
        @first_displayed_message += 1 unless generated_lines >= @scroll
        break if generated_lines >= @scroll + @height

        @first_undisplayed_message += 1
      end
    end

    def print_display(offset = 0)
      # @todo still in work
      messages =
        @display[@first_displayed_message...@first_undisplayed_message].reverse
      lines_before = @display[...@first_displayed_message].map(&:length).sum
      lines_in = messages.map(&:length).sum
      bottom_cutoff = @scroll - lines_before
      top_cutoff = lines_in - @height - bottom_cutoff
      bottom_cutoff -= offset if offset.negative?
      top_cutoff -= offset if offset.positive?
      top_cutoff.clamp(0, lines_in)
      bottom_cutoff.clamp(0, lines_in)
      @win.setpos([-top_cutoff, 0].max, 0)
      messages.each_with_index do |lines, i|
        start = top_cutoff.max if i.zero?
        stop = -(bottom_cutoff + 1) if i == messages.length - 1
        Markup.print_lines(@win, lines, start..stop)
      end
    end
  end
end
