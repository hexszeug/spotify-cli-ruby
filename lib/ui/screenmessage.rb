# frozen_string_literal: true

module UI
  class ScreenMessage
    def initialize(markup)
      update(markup)
    end

    def changed? = @changed

    ##
    # Sets the new content of the message to `markup`.
    # **Must not be overwritten!
    # To change behavior of subclasses overwrite
    # the private method `read_content`.**
    #
    def update(markup)
      @changed = true
      read_content(markup)
      self
    end

    ##
    # Returns the lines in the message and inserts line breaks when needed.
    # Can be overwritten by subclasses to implement custom behavior.
    #
    # @param max_length [Integer]
    #
    # @return [Array] of [Array] of [String|Hash] (hashes are markup tokens)
    def lines(max_length)
      @changed = false
      @lines.collect_concat { |line| line_break(line, max_length) }
    end

    private

    ##
    # Can be overwitten by subclasses for cutom behaviour
    def read_content(markup)
      if markup.empty?
        @lines = [['']]
        return
      end

      @lines = markup.split(/\n|\r\n/).map do |line|
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
      # line_strs = [line.grep(String).join]
      # line_strs.each_with_index do |line_str, i|
      #   next unless line_str.length > max_length

      #   split = line_str.rindex(/\s/, max_length)
      #   split ||= max_length
      #   new_line = line_str.slice!(split..).lstrip

      #   new_line.slice!(...s)
      #   next if new_line.empty?

      #   lines.insert(i + 1, new_line)
      # end
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
