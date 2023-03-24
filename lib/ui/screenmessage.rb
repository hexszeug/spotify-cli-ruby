# frozen_string_literal: true

module UI
  class ScreenMessage
    def initialize(markup)
      update(markup)
    end

    def changed? = @changed

    ##
    # Sets the new content of the message to `markup`.
    # Can be overwritten by subclasses to implement custom behavior.
    #
    def update(markup)
      read_markup(markup)
    end

    ##
    # Returns the lines in the message and inserts line breaks when needed.
    # Can be overwritten by subclasses to implement custom behavior.
    #
    # @param max_length [Integer]
    #
    # @return [Array] of [Array] of [String|Hash] (hashes are markup tokens)
    def lines(max_length)
      @lines.map { |line| line_break(line, max_length) }.flatten
    end

    private

    def read_markup(markup)
      raise ArgumentError, 'not a string' unless markup.is_a?(String)

      @changed = true
      if markup.empty?
        @lines = ['']
        return
      end

      @lines = markup.split(/\n|\r\n/).map do |line|
        Markup.parse(line)
      end
      @lines.each do |line| # @todo remove debug
        puts line.to_s
      end
      nil
    end

    def line_break(line, _max_length)
      # @todo implement
      line
    end
  end
end

# @todo remove debug script
if caller.empty?
  require 'curses'
  require_relative 'colors'
  UI::Colors.start
  Curses.close_screen
  require_relative 'markup'
  UI::ScreenMessage.new <<~TEXT
    Lorem 500$$$$$#aaaaaa whats that
  TEXT
end
