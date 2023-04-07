# frozen_string_literal: true

module UI
  ##
  # Markups can be used to generate and store colored and formatted texts.
  # To create a markup just pass a markup text to the constructor of this class.
  # A markup text is just a normal string (single/multi-line) which can contain
  # markup sequences to change the look of the text after the secquence.
  # The sequences apply until the next sequence that changes the same attribute
  # or until the end of the markup.
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
  # Color modifiers can be prefixed by a `@` to
  # set the background color instead of the foreground.
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
  class Markup
    attr_reader :markup

    def initialize(arg)
      replace(arg)
    end

    def replace(arg)
      @markup =
        case arg
        when String then Parser.parse(arg)
        when Array then Utils.compact(arg)
        when Markup then arg.markup
        else raise TypeError,
                   "no implicit conversion of #{arg.class} into #{String}"
        end
      self
    end

    def length
      Utils.length(@markup)
    end

    def chomp
      Markup.new(Utils.chomp(@markup))
    end

    ##
    # @param index [Integer]
    # @param start [Integer], length [Integer]
    # @param range [Range]
    def slice(*args)
      arg1, arg2 = args
      range =
        case arg1
        when Range then arg1
        when Integer
          if arg2.nil?
            arg1..arg1
          else
            arg1 += length if arg1.negative?
            arg1..(arg1 + arg2)
          end
        else 0...0
        end
      Markup.new(Utils.slice(@markup, range))
    end

    alias [] slice

    def height
      lines.length
    end

    def width
      lines.map(&:chomp).map(&:length).max
    end

    def lines
      raw_lines = markup_text.lines.map { |line| Markup.new(line) }
      raw_lines.each_cons(2) do |line_a, line_b|
        line_b.replace(line_a.markup.grep(Hash) + line_b.markup)
      end
    end

    def print_to(window, state: {})
      Printer.print(window, @markup, state:)
    end

    def markup_text
      Parser.generate(@markup)
    end

    alias to_s markup_text

    def +(other)
      case other
      when String then self + Markup.new(other)
      when Array then Markup.new(@markup + other)
      when Markup then Markup.new(@markup + other.markup)
      else raise TypeError,
                 "no implicit conversion of #{arg.class} into #{Markup}"
      end
    end

    def ==(other)
      @markup == other.markup
    end

    alias eql? ==

    def hash
      @markup.hash
    end
  end
end

require_relative 'markup/colors'
require_relative 'markup/parser'
require_relative 'markup/printer'
require_relative 'markup/utils'
