# frozen_string_literal: true

require 'curses'

module UI
  ##
  # return listener or suggestion provider may raise this error
  # it is automatically rescued and printed to the output
  class Error < StandardError
    attr_reader :print_msg

    def initialize(print_msg)
      super()

      @print_msg = print_msg
    end
  end

  class << self
    attr_reader :input, :output

    ##
    # blocks the current thread until stop_loop
    # is called or the process is killed
    def start_loop
      unless Thread.current == Thread.main
        raise ThreadError, 'not the main thread'
      end
      return if @running

      # initialize protection of stderr
      abort_on_exception = Thread.abort_on_exception
      report_on_exception = Thread.report_on_exception
      Thread.abort_on_exception = true
      Thread.report_on_exception = false

      # initialite curses
      Curses.init_screen
      Curses.start_color
      Curses.noecho
      Curses.cbreak
      Curses.nl

      # start colors
      Markup::Colors.start

      # initialize io
      @input = Input.new
      @output = Output.new

      # set initial sizes
      resize

      # loop
      @running = true
      begin
        while @running
          @input.read
          @output.refresh
          @input.refresh
        end
      rescue Exception => e # rubocop:disable Lint/RescueException
        Curses.close_screen
        retry if @crash_handler&.call(e)

        raise
      end
    ensure
      # stop colors
      Markup::Colors.stop

      # stop curses
      Curses.close_screen

      # reset stderr handling
      Thread.abort_on_exception = abort_on_exception
      Thread.report_on_exception = report_on_exception
    end

    def stop_loop
      @running = false
    end

    def print(screen_message)
      @output&.print(screen_message)
    end

    def returns(&block)
      @return_listener = block
    end

    def suggests(&block)
      @suggestion_provider = block
    end

    ##
    # Passed block is called if a thread crashes due to an exception
    # while the main ui loop is running.
    # The expection is passed to the block.
    #
    # If the block returns a truthy value the exception is ignored
    # and the ui loop continues.
    # Otherwise the ui shuts down and the exception is reraised.
    def on_crash(&block)
      @crash_handler = block
    end

    ##
    # **internal use only**
    def on_return(str)
      @return_listener&.call(str)
    rescue Error => e
      print(ScreenMessage.new(e.print_msg))
    end

    ##
    # **internal use only**
    def on_suggest(str, return_errors: false)
      @suggestion_provider&.call(str) || []
    rescue Error => e
      return e if return_errors

      []
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

require_relative 'ui/markup'
require_relative 'ui/screenmessage'
require_relative 'ui/input'
require_relative 'ui/output'
require_relative 'ui/print_utils'
