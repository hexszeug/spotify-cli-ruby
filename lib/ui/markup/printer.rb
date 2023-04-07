# frozen_string_literal: true

require 'curses'

module UI
  class Markup
    module Printer
      CURSES_ATTRIBUTES = {
        bold: Curses::A_BOLD,
        underline: Curses::A_UNDERLINE,
        reverse: Curses::A_REVERSE,
        blink: Curses::A_BLINK,
        dim: Curses::A_DIM
      }.freeze

      class << self
        def print(window, markup, state: {})
          state = Utils.merge_tokens(Parser::RESET_STATE, state)
          apply_state(window, state)
          markup.each do |token|
            if token.is_a?(String)
              window.addstr(token)
              next
            end

            state = Utils.merge_tokens(state, token)
            apply_state(window, state)
          end
          state
        end

        private

        def apply_state(window, state)
          window.attrset(
            state.filter do |key, value|
              CURSES_ATTRIBUTES.key?(key) && value == :set
            end.map do |key, _value|
              CURSES_ATTRIBUTES[key]
            end.reduce(0, :|)
          )
          window.color_set(
            Colors.color_pair(state[:color], state[:bg_color])
          )
        end
      end
    end
  end
end
