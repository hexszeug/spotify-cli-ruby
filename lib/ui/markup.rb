# frozen_string_literal: true

module UI
  ##
  # Module providing utility function for handling markup texts.
  #
  # ## Markup sequences
  # Markup sequences are escaped by `$`.
  # *(`$$` produces a single dolor sign in the text.)*
  # Each new markup sequence has to be escaped independently.
  # You cannot implicitly chain them.
  # (`$r*` doesn't work but `$r$*` does.)
  #
  # There are three types of markup sequences:
  # - color modifiers
  # - attribute modifiers
  # - special reset sequences
  #
  # ### Color modifiers:
  # A hex color code like `#29abe3`.
  #
  # Additionally there are some short forms for frequently used colors
  # from the terminal's color scheme.
  # Lowercase letters can be used for the light variant of that color.
  # - `D` black (dark)
  # - `R` red
  # - `G` green
  # - `Y` yellow
  # - `B` blue
  # - `P` purple
  # - `C` cyan
  # - `W` white
  #
  # *Please be aware that the user could change the colors in
  # their terminal emulator. This are only the default values.*
  #
  # Color modifiers can be suffixed by a `b` to
  # set the background color instead of the foreground.
  # **If and ONLY IF the color change is followed by a `b` you can
  # explicitly specify that you set the foreground color with a `f`.**
  #
  # ### Attribute modifiers:
  # - `*` bold
  # - `_` underline
  # - `!` reverse
  # - `~` blink
  # - `%` dim
  # With no prefix the attribute is toggled. You can reset or set
  # the attributes by adding the following prefixes:
  # - `0` reset
  # - `1` set
  #
  # ### Special reset sequences:
  # There are some special reset sequences listed here:
  # - `0a` reset all attributes
  # - `0c` reset forground color (to terminal's default)
  # - `0b` reset background color
  # - `0C` reset foreground and background color
  # - `0A` reset attributes, forground and background color
  module Markup
    # colors
    COLORS = %w[D R G Y B P C W d r g y b p c w].each_with_index.to_h.freeze

    # attributes
    attrs = {
      bold: ['*', Curses::A_BOLD],
      underline: ['_', Curses::A_UNDERLINE],
      reverse: ['!', Curses::A_REVERSE],
      blink: ['~', Curses::A_BLINK],
      dim: ['%', Curses::A_DIM]
    }
    ATTRIBUTES =
      attrs.transform_values(&:first).invert.freeze
    CURSES_ATTRIBUTES = Hash.new(0).update(
      attrs.transform_values(&:last)
    ).freeze

    # attrubute prefixes
    ATTR_PREFIXES = Hash.new(:toggle).update(
      '0' => :reset,
      '1' => :set
    ).freeze

    # resets
    resets = {
      'c' => { color: -1 }.freeze,
      'b' => { bg_color: -1 }.freeze,
      'C' => { color: -1, bg_color: -1 }.freeze,
      'a' => ATTRIBUTES.each_value.to_h { |key| [key, :reset] }.freeze
    }
    RESET_STATE = resets.each_value.reduce(:merge).freeze
    resets['A'] = RESET_STATE
    RESETS = resets.freeze

    # regexp
    REGEXP = Regexp.new(<<~REGEXP.gsub(/\s/, '')).freeze
      \\$
      (
        (?:
          \\$ |
          (?:
            # [0-9a-fA-F]{6} |
            [#{UI::Markup::COLORS.keys.join}]
          )(?: b | f (?=b))? |
          [#{UI::Markup::ATTR_PREFIXES.keys.join}]? [#{UI::Markup::ATTRIBUTES.keys.join}] |
          0 [#{UI::Markup::RESETS.keys.join}]
        )?
      )
    REGEXP

    class << self
      ##
      # Transforms a **markup text** into a **markup array**.
      # **Markup arrays** consist of strings representing text
      # and hashes representing markup modifier.
      # Those modifiers set attributes or color of the text until
      # they are changed by another modifier.
      def parse(markup)
        markup.split(REGEXP).map.with_index do |str, i|
          i.even? ? str : parse_markup_token(str)
        end.reject(&:empty?).chunk(&:class).map do |klass, values|
          klass == String ? values.join : merge_markup_tokens(*values)
        end
      end

      ##
      # @param window [Curses::Window]
      # @param markup [Array]
      # @param state [Hash]
      def print(window, markup, state: {})
        state = merge_markup_tokens(RESET_STATE, state)
        markup.each do |token|
          if token.is_a?(String)
            window.addstr(token)
            next
          end

          state = merge_markup_tokens(state, token)
          apply_state(window, state)
        end
        state
      end

      def print_lines(window, lines, range = 0.., state: {})
        state = merge_markup_tokens(RESET_STATE, state)
        state = lines[...range.begin].collect_concat do |line|
          line.grep(Hash)
        end.reduce(state) do |*tokens|
          merge_markup_tokens(*tokens)
        end
        lines[range].each do |line|
          state = print(window, line + ["\n"], state:)
        end
        state
      end

      private

      ##
      # @param token_str [String]
      # @return [Hash] markup token
      def parse_markup_token(token_str)
        token_str = +token_str
        return {} if token_str.empty?

        # colors
        if token_str.start_with?('#')
          color = Markup::Colors.hex_color_id(token_str[..6])
          key = token_str[7] == 'b' ? :bg_color : :color
          return { key => color }
        end
        if (color = COLORS[token_str[0]])
          key = token_str[1] == 'b' ? :bg_color : :color
          return { key => color }
        end

        # attributes
        action = ATTR_PREFIXES[token_str[0]]

        if (attribute = ATTRIBUTES[token_str[-1]])
          return { attribute => action }
        end

        if (reset = RESETS[token_str[-1]]) && action == :reset
          return reset
        end

        token_str
      end

      ##
      # @param *tokens [Hash]
      # @return [Hash] markup token
      def merge_markup_tokens(*tokens)
        tokens.reduce do |token_a, token_b|
          token_a.merge(token_b) do |key, old_val, new_val|
            next new_val if %i[color bg_color].include?(key)
            next new_val unless new_val == :toggle
            next :reset if old_val == :set
            next :set if old_val == :reset

            nil
          end.compact
        end
      end

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

require_relative 'markup/colors'
