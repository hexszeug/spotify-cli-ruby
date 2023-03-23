# frozen_string_literal: true

module UI
  class ScreenMessage
    COLORS = %w[D R G Y B P C W d r g y b p c w].each_with_index.to_h.freeze
    ATTRIBUTES = {
      '*' => :bold,
      '_' => :underline,
      '^' => :reverse,
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
          [#{ATTR_PREFIXES.keys.join}]?
          [#{ATTRIBUTES.keys.join}#{RESETS.keys.join}]
        )|(?:
          (?:
            (?:#[0-9a-fA-f]{6})
            |[#{COLORS.keys.join}]
          )
          b?
        )
      )?
    REGEXP

    def initialize(markup)
      read_markup(markup)
    end

    def update(markup)
      read_markup(markup)
    end

    def changed? = @changed

    private

    ##
    # markup text may contain the following control sequences escaped by `$`:
    #
    # `0` + *symbol* = reset symbol
    # `1` + *symbol* = set symbol
    # `b` + *color* = set background color
    # *symbol* = toggle symbol
    #
    # symbols:
    # - `*` = bold
    # - `_` = underline
    # - `^` = reverse
    # - `~` = blink
    # - `%` = dim
    # - single letter color see [UI::Colors::color_id] **(allways set)**
    # - `#` + 6 digit hex color **(allways set)**
    # special symbols *(work only with reset)*:
    # - `A` = reset color and attributes
    # - `a` = reset all attributes
    # - `c` = reset color (to terminal's default)
    # - `b` = reset background color
    # - `C` = reset color and background color
    def read_markup(markup)
      raise ArgumentError, 'not a string' unless markup.is_a?(String)

      @changed = true
      if markup.empty?
        @lines = ['']
        return
      end

      @lines = markup.split(/\n|\r\n/).map do |line|
        line.split(REGEXP).map.with_index do |str, i|
          i.even? ? str : parse_markup_token(str)
        end.delete_if(&:empty?).chunk(&:class).map do |klass, values|
          klass == String ? values.first : merge_markup_tokens(*values)
        end
      end
      @lines.each do |line| # @todo remove debug
        puts line.to_s
      end
      nil
    end

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
      token_str.slice!(0) unless action == ATTR_PREFIXES.default
      if (attribute = ATTRIBUTES[token_str])
        return { attribute => action }
      end

      if (reset = RESETS[token_str]) && action == :reset
        return reset
      end

      {}
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

if caller.empty?
  require_relative 'colors'
  UI::ScreenMessage.new <<~TEXT
    $0ALorem ipsum dolor sit amet, $*consetetur$* sadipscing elitr,
    $rsed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat,
    sed diam voluptua.$*$0*$*
  TEXT
end
