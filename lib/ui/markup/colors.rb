# frozen_string_literal: true

module UI
  class Markup
    module Colors
      class << self
        COLOR_SCHEME_SIZE = 16
        CURSES_COLOR_BASE = 1001
        STR_COLOR_BASE = 256

        def start
          return false unless (@enabled = Curses.can_change_color?)

          Curses.start_color
          Curses.use_default_colors

          @distinct_colors = Curses.colors
          @pairs = Hash.new do |hash, key|
            if key.is_a?(Array) &&
               key.length == 2 &&
               Curses.init_pair((id = hash.length), *key)
              hash[key] = id
            else
              0
            end
          end
          @pairs[[-1, -1]]

          return 0 unless (@enabled_hex = @distinct_colors > COLOR_SCHEME_SIZE)

          @color_base =
            [Math.cbrt(@distinct_colors - COLOR_SCHEME_SIZE).to_i, 256].min
          @distinct_hex_colors = @color_base**3
          @distinct_hex_colors.times do |i|
            color_array = decode_int_color(i)
            curses_color =
              transform_base(color_array, @color_base, CURSES_COLOR_BASE)
            Curses.init_color(i + COLOR_SCHEME_SIZE, *curses_color)
          end
          @distinct_hex_colors
        end

        def stop
          @enabled = @enabled_hex = false
        end

        ##
        # @param hex_color [String] `#a3047b` for example
        # @return [Integer] the color id of the color
        def hex_color_id(hex_color)
          return unless @enabled_hex
          return -1 unless hex_color =~ /#[0-9a-fA-f]{6}/

          color_array_hex =
            hex_color[1..6]
            .each_char
            .each_slice(2)
            .map { |m, l| (m + l).to_i(16) }
            .to_a
          color_array =
            transform_base(color_array_hex, STR_COLOR_BASE, @color_base)
          encode_int_color(color_array) + COLOR_SCHEME_SIZE
        end

        ##
        # @return hex_color_id [Integer] the color id of the color
        # @param [String] `#a3047b` for example
        def hex_color_string(hex_color_id)
          return unless @enabled_hex

          hex_color_id -= COLOR_SCHEME_SIZE
          return unless hex_color_id >= 0 || hex_color_id < @distinct_hex_colors

          color_array = decode_int_color(hex_color_id)
          color_array_hex =
            transform_base(color_array, @color_base, STR_COLOR_BASE)
          hex_color = color_array_hex.map { |c| c.to_s(16).ljust(2, '0') }.join
          "##{hex_color}"
        end

        ##
        #
        def color_pair(foreground, background)
          @pairs[[foreground, background]] if @enabled
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
        def encode_int_color(color_array,
                             base: @color_base || CURSES_COLOR_BASE)
          r, g, b = color_array
          (r * (base**2)) + (g * base) + b
        end
      end
    end
  end
end
