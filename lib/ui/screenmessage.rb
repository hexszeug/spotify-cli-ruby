# frozen_string_literal: true

module UI
  class ScreenMessage
    # @todo (logic bug) move generation of markup lines from read_content to lines
    # @todo use decorator pattern instead of inheritance for custom generation
    def initialize(markup)
      update(markup)
    end

    def changed? = @changed

    ##
    # Sets the new content of the message to `markup`.
    # **Must not be overwritten!
    # To change behavior of subclasses overwrite
    # the private method `update_content`.**
    #
    def update(markup)
      @changed = true
      update_content(markup)
      self
    end

    ##
    # Returns the lines in the message and inserts line breaks when needed.
    # **Must not be overwritten!
    # To change behavior of subclasses overwrite
    # the private method `generate_markup`.**
    #
    # @param max_length [Integer]
    #
    # @return [Array] of [Array] of [String|Hash] (hashes are markup tokens)
    def lines(max_length)
      @changed = false
      generate_markup(max_length)
    end

    private

    ##
    # Can be overwitten by subclasses for cutom behavior
    def update_content(markup)
      @lines = parse_markup(markup)
    end

    ##
    # Can be overwitten by subclasses for cutom behavior
    def generate_markup(max_length)
      @lines.collect_concat { |line| line_break(line, max_length) }
    end

    def parse_markup(markup)
      return [['']] if markup.empty?

      markup.split(/\n|\r\n/).map do |line|
        Markup.parse(line)
      end
    end

    def line_break(long_line, max_length)
      lines = [long_line]
      lines.each do |line|
        str = line.grep(String).join.rstrip
        next unless str.length > max_length

        index = str.rindex(/\s/, max_length) || max_length
        lines.pop
        lines.push(*split_line_at(line, index))
      end
      lines
    end

    def split_line_at(line, index)
      curr_index = 0
      line_a = []
      line_b = line.drop_while do |token|
        line_a.push(token)
        next true unless token.is_a?(String)

        curr_index += token.length
        curr_index <= index
      end
      return [line, []] if curr_index < index

      overflow = curr_index - index
      line_a[-1] = line_a.last[...-overflow]
      line_a.pop if line_a.last.empty?
      line_b[0] = line_b.first[-overflow..].lstrip
      [line_a, line_b]
    end
  end
end
