# frozen_string_literal: true

require 'curses'

module UI
  class << self
    attr_reader :input, :output

    ##
    # blocks the current thread until stop_loop
    # is called or the process is killed
    def start_loop
      return if @running

      Curses.init_screen
      Curses.start_color
      Curses.noecho
      Curses.cbreak
      Curses.nl

      @input = Input.new
      @output = Output.new

      resize

      @running = true
      while @running
        @input.read
        @output.refresh
        @input.refresh
      end
    end

    def stop_loop
      @running = false
      Curses.close_screen
    end

    def print(str = nil, &)
      @output&.print { str } unless str.nil?
      @output&.print(&) if block_given?
    end

    def returns(&block)
      @return_listener = block
    end

    def on_return(str)
      @return_listener&.call(str)
    end

    ##
    # **internal use only**
    def resize
      @input.resize
      @output.resize
      Curses.clear
      Curses.refresh
    end

    ##
    # **internal use only**
    # utility method
    def resize_window(
      win,
      top_left_x,
      top_left_y,
      bottom_right_x,
      bottom_right_y
    )
      top_left_x = Curses.cols + top_left_x if top_left_x.negative?
      top_left_y = Curses.lines + top_left_y if top_left_y.negative?
      bottom_right_x = Curses.cols + bottom_right_x if bottom_right_x.negative?
      bottom_right_y = Curses.lines + bottom_right_y if bottom_right_y.negative?
      win.resize(bottom_right_y - top_left_y + 1,
                 bottom_right_x - top_left_x + 1)
      win.move(top_left_y, top_left_x)
    end
  end
end

require_relative 'ui/input'
require_relative 'ui/output'
