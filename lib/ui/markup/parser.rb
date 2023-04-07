# frozen_string_literal: true

module UI
  class Markup
    module Parser
      # colors
      COLORS = %w[D R G Y B P C W d r g y b p c w].each_with_index.to_h.freeze
      COLOR_TOKENS = COLORS.invert.freeze

      # attributes
      ATTRIBUTE_TOKENS = {
        bold: '*',
        underline: '_',
        reverse: '!',
        blink: '~',
        dim: '%'
      }.freeze
      ATTRIBUTES = ATTRIBUTE_TOKENS.invert.freeze

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
            @? (?:
              # [0-9a-fA-F]{6} |
              [#{COLORS.keys.join}]
            ) |
            [#{ATTR_PREFIXES.keys.join}]? [#{ATTRIBUTES.keys.join}] |
            0 [#{RESETS.keys.join}]
          )?
        )
      REGEXP

      class << self
        def parse(markup_text)
          Utils.compact(
            markup_text.split(REGEXP).map.with_index do |str, i|
              i.even? ? str : parse_markup_token(str)
            end
          )
        end

        def generate(markup)
          markup.map do |token|
            if token.is_a?(String)
              token.gsub('$', '$$')
            else
              generate_markup_token(token)
            end
          end.join
        end

        private

        def parse_markup_token(token_str)
          return {} if token_str.empty?

          # colors
          if token_str.start_with?('@')
            bg = true
            token_str = token_str[1..]
          end
          if token_str.start_with?('#')
            color = Markup::Colors.hex_color_id(token_str)
            key = bg ? :bg_color : :color
            return { key => color }
          end
          if (color = COLORS[token_str[0]])
            key = bg ? :bg_color : :color
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

        def generate_markup_token(token)
          token.map do |key, value|
            if %i[color bg_color].include?(key)
              prefix = '@' if key == :bg_color
              token =
                if value == -1
                  prefix = '0'
                  key == :color ? 'c' : 'b'
                elsif value < COLOR_TOKENS.length
                  COLOR_TOKENS[value]
                else
                  Colors.hex_color_string(value)
                end
            else
              prefix = '0' if value == :reset
              prefix = '1' if value == :set
              token = ATTRIBUTE_TOKENS[key]
            end
            "$#{prefix}#{token}"
          end.join
        end
      end
    end
  end
end
