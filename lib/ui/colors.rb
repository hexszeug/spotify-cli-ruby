# frozen_string_literal: true

module UI
  module Colors
    COLOR_SCHEME_SIZE = 16

    class << self
      DISTINCT_POSITIVE_VALUES_C_SIGNED_SHORT = 0x8000

      CURSES_COLOR_BASE = 1001
      STR_COLOR_BASE = 256

      def start
        return false unless (@enabled = Curses.can_change_color?)

        Curses.start_color
        Curses.use_default_colors

        @distinct_colors = Curses.colors
        @distinct_pairs =
          [Curses.color_pairs, DISTINCT_POSITIVE_VALUES_C_SIGNED_SHORT].min
        return @enabled = false if @distinct_colors < COLOR_SCHEME_SIZE

        COLOR_SCHEME_SIZE.times do |i|
          Curses.init_pair(i + 1, i, -1)
        end

        return true unless (@enabled_hex = @distinct_colors > COLOR_SCHEME_SIZE)

        @color_base =
          [Math.cbrt(@distinct_colors - COLOR_SCHEME_SIZE).to_i, 256].min
        @distinct_hex_colors = @color_base**3
        @distinct_hex_colors.times do |i|
          color_array = decode_int_color(i)
          curses_color =
            transform_base(color_array, @color_base, CURSES_COLOR_BASE)
          Curses.init_color(i + COLOR_SCHEME_SIZE, *curses_color)
        end
      end

      def stop; end

      ##
      #
      def hex_color_id(hex_color)
        return -1 unless hex_color =~ /#[0-9a-fA-f]{6}/

        color_array_hex = hex_color[1..6].each_slice(2) { |v| v.to_i(16) }.to_a
        color_array =
          transform_base(color_array_hex, STR_COLOR_BASE, @color_base)
        encode_int_color(color_array) + COLOR_SCHEME_SIZE
      end

      private

      ##
      # @param color_array [Array] color array `[r, g, b]` in base `from_base`
      # @param from_base [Integer] base of `color_array`
      # @param to_base [Integer] destination base
      #
      # @return [Array] color array `[r, g, b]` in base `to_base`
      def transform_base(color_array, from_base, to_base)
        from_base -= 1
        to_base -= 1
        color_array.map do |v|
          (v.to_f / from_base * to_base).round
        end
      end

      ##
      # @param color_int [Integer] single color integer in any base
      # @param base [Integer] base of `color`
      #
      # @return [Array] color array `[r, g, b]` (in same base)
      def decode_int_color(color_int, base: @color_base || CURSES_COLOR_BASE)
        b = color_int % base
        g = color_int / base % base
        r = color_int / (base**2) % base
        [r, g, b]
      end

      ##
      # @param color_array [Array] color array `[r, g, b]` in any base
      # @param base [Integer] base of `color_array`
      #
      # @return [Integer] color integer (in same base)
      def encode_int_color(color_array, base: @color_base || CURSES_COLOR_BASE)
        r, g, b = color_array
        (r * (base**2)) + (g * base) + b
      end
    end
  end
end
