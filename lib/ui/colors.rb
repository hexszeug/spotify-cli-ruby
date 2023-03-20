# frozen_string_literal: true

module UI
  module Colors
    DISTINCT_POSITIVE_VALUES_C_SIGNED_SHORT = 0x8000

    ##
    # uppercase = dark, lowercase = bright
    #
    # d = black (dark)
    # r = red
    # g = green
    # y = yellow
    # b = blue
    # p = purple
    # c = cyan
    # w = white
    COLOR_SCHEME =
      %w[D R G Y B P C W d r g y b p c w].each_with_index.to_h.freeze
    CURSES_COLOR_BASE = 1001
    STR_COLOR_BASE = 256

    class << self
      def start
        return false unless (@enabled = Curses.can_change_color?)

        Curses.start_color
        Curses.use_default_colors

        @distinct_colors = Curses.colors
        @distinct_pairs =
          [Curses.color_pairs, DISTINCT_POSITIVE_VALUES_C_SIGNED_SHORT].min
        return @enabled = false if @distinct_colors < COLOR_SCHEME.size

        COLOR_SCHEME.size.times do |i|
          Curses.init_pair(i + 1, i, -1)
        end

        return true unless (@enabled_hex = @distinct_colors > COLOR_SCHEME.size)

        @color_base =
          [Math.cbrt(@distinct_colors - COLOR_SCHEME.size).to_i, 256].min
        @distinct_hex_colors = @color_base**3
        @distinct_hex_colors.times do |i|
          color_array = decode_int_color(i, base: @color_base)
          curses_color =
            transform_base(color_array, @color_base, CURSES_COLOR_BASE)
          Curses.init_color(i + COLOR_SCHEME.size, *curses_color)
        end
      end

      def stop; end

      # @todo uncomment debug
      # private

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
      def decode_int_color(color_int, base: STR_COLOR_BASE)
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
      def encode_int_color(color_array, base: STR_COLOR_BASE)
        r, g, b = color_array
        (r * (base**2)) + (g * base) + b
      end
    end
  end
end

if caller.empty?
  # @todo remove debug script
  def print_colors(n = 32)
    n.times do |i|
      Curses.addstr("#{i}: #{Curses.color_content(i)}    ")
    end
  end

  def print_pairs(n = 32)
    n.times do |i|
      Curses.addstr("#{i}: #{Curses.pair_content(i)}     ")
    end
  end

  def show_attrs
    const = Curses.constants.filter do |v|
              /^A/ =~ v.to_s
            end.to_h { |c| [Curses.const_get(c), c] }
    a = Curses::A_ATTRIBUTES.to_s(2)
    a.count('1').times do |i|
      v = 1 << (a.count('0') + i)
      Curses.attrset(v)
      Curses.addstr("#{const[v] || v.to_s(2)}\n")
    rescue RangeError
      next
    end
    Curses.attrset(0)
  end

  def show_colors
    Curses.attrset(0)
    216.times do |i|
      Curses.init_pair(i + 1, -1, i + 16)
      Curses.stdscr.color_set(i + 1)
      Curses.addstr(' ')
    end
    Curses.stdscr.color_set(0)
  end

  def rainbow
    Curses.attrset(0)
  end

  begin
    require 'curses'
    Curses.init_screen
    Curses.nocbreak
    Curses.echo
    Curses.stdscr.scrollok(true)
    Curses.refresh
    UI::Colors.start
    # show_colors
    loop do
      Curses.refresh
      begin
        str = Curses.getstr.chomp
        break if str == 'q'

        Curses.addstr(eval(str).to_s + "\n")
      rescue Exception => e
        Curses.addstr(e.full_message + "\n")
      end
    end
  ensure
    Curses.close_screen
  end
end
