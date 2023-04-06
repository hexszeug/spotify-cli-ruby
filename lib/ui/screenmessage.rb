# frozen_string_literal: true

module UI
  class ScreenMessage
    attr_reader :content

    def changed?
      @changed
    end

    def initialize(content, type: nil)
      update(content, type:)
    end

    def touch
      @changed = true
    end

    def update(content, type: nil)
      @changed = true
      @content = content
      @decorator = type&.new(self)
      self
    end

    ##
    # @return [Array] of [Array] of [String|Hash] (hashes are markup tokens)
    def lines(max_length)
      @changed = false
      markup = @decorator&.generate(max_length) || @content
      lines = parse_markup(markup)
      crop_lines(lines, max_length)
    end

    private

    def parse_markup(markup)
      return [['']] if markup.empty?

      markup.split(/\n|\r\n/).map do |line|
        Markup.parse(line)
      end
    end

    def crop_lines(lines, max_length)
      lines.collect_concat { |line| line_break(line, max_length) }
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
