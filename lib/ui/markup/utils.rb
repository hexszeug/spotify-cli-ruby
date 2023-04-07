# frozen_string_literal: true

module UI
  class Markup
    module Utils
      class << self
        def raw_text(markup)
          markup.grep(String).join
        end

        def length(markup)
          raw_text(markup).length
        end

        def lines(markup)
          Parser.generate(compact(markup)).lines.map do |line|
            Parser.parse(line)
          end.each_cons(2) do |line_a, line_b|
            line_b.unshift(*line_a.grep(Hash))
          end
        end

        def width(markup)
          lines(markup).map { |line| length(chomp(line)) }.max
        end

        def height(markup)
          lines(markup).length
        end

        def chomp(markup)
          last_string = markup.rindex { |token| token.is_a?(String) }
          markup.map.with_index do |token, i|
            i == last_string ? token.chomp : token
          end
        end

        def strip(markup)
          lstrip(rstrip(markup))
        end

        def lstrip(markup)
          i = raw_text(markup).index(/\S/)
          slice(markup, i..)
        end

        def rstrip(markup)
          i = raw_text(markup).rindex(/\S/)
          slice(markup, ..i)
        end

        def slice(markup, range)
          start, stop = absolute_start_stop(range, length(markup))
          return markup.grep(Hash) if stop < start

          i = 0
          markup.map do |token|
            next if i > stop
            next token if token.is_a?(Hash)
            next if i + token.length < start

            s = start - i if i < start
            e = stop - i if i + token.length > stop
            i += token.length
            token[s..e]
          end.compact
        end

        def scale(markup, max_width)
          lines(markup).map do |long_line|
            lines = [long_line]
            lines.each do |line|
              lines.pop
              line = rstrip(line)
              next lines.push(line) if width(line) <= max_width

              i = raw_text(line).rindex(/\s/, max_width) || max_width
              lines.push(slice(line, ...i))
              lines.push(lstrip(slice(line, i..)))
            end
            lines.map { |line| line + [$/] }
          end.flatten
        end

        def compact(markup)
          markup.reject(&:empty?).chunk(&:class).map do |klass, values|
            klass == String ? values.join : merge_tokens(*values)
          end
        end

        def merge_tokens(*tokens)
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

        private

        def absolute_start_stop(range, length)
          start = range.begin || 0
          stop = range.end || (range.exclude_end? ? length : length - 1)
          unless start.instance_of?(Integer)
            raise TypeError,
                  "no implicit conversion of #{start.class} to #{Integer}"
          end
          unless stop.instance_of?(Integer)
            raise TypeError,
                  "no implicit conversion of #{stop.class} to #{Integer}"
          end

          start += length if start.negative?
          stop += length if stop.negative?
          stop -= 1 if range.exclude_end?
          start = start.clamp(0, length - 1)
          stop = stop.clamp(0, length - 1)
          [start, stop]
        end
      end
    end
  end
end
