# frozen_string_literal: true

module UI
  ##
  # Module providing utility function for handling **markup text**.
  #
  # A **markup text** is a string which can cointain markup sequences
  # escaped by `$`. You can escape it with `$$` to use the character.
  # **WARNING:** Each new markup sequence has to be escaped independently
  # by `$` even if it is next to another. (`$r$*` not `$r*`)
  #
  # There are three types of markup sequences:
  # - color modifiers
  # - attribute modifiers
  # - special reset sequences
  #
  # **Color modifiers:**
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
  #
  # **Attribute modifiers:**
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
  # **Special reset sequences:**
  # There are some special reset sequences listed here:
  # - `0a` reset all attributes
  # - `0c` reset forground color (to terminal's default)
  # - `0b` reset background color
  # - `0C` reset foreground and background color
  # - `0A` reset attributes, forground and background color
  module Markup
    COLORS = %w[D R G Y B P C W d r g y b p c w].each_with_index.to_h.freeze
    ATTRIBUTES = {
      '*' => :bold,
      '_' => :underline,
      '!' => :reverse,
      '~' => :blink,
      '%' => :dim
    }.freeze
    ATTR_PREFIXES = Hash.new(:toggle).update(
      '0' => :reset,
      '1' => :set
    ).freeze
    RESETS =
      begin
        resets = {
          'c' => { color: -1 },
          'b' => { bg_color: -1 },
          'C' => { color: -1, bg_color: -1 },
          'a' => ATTRIBUTES.each_value.to_h { |key| [key, :reset] }
        }
        resets['A'] = resets.each_value.reduce(:merge)
        resets.freeze
      end
    REGEXP = Regexp.new(<<~REGEXP.gsub(/\s/, '')).freeze
      \\$
      (
        (?:
          \\$ |
          # [0-9a-fA-F]{6} b? |
          [#{UI::Markup::COLORS.keys.join}] b? |
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
        end.delete_if(&:empty?).chunk(&:class).map do |klass, values|
          klass == String ? values.join : merge_markup_tokens(*values)
        end
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
          color = Colors.hex_color_id(token_str[1..6])
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
    end
  end
end
