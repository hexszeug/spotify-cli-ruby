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

        def lines(markup, safe: true)
          # @todo reimplement in terms of slice() for performance improvement
          lines = Parser.generate(compact(markup)).lines.map do |line|
            Parser.parse(line)
          end
          if safe
            lines.each_cons(2) do |line_a, line_b|
              line_b.unshift(*line_a.grep(Hash))
            end
          end
          lines
        end

        def width(markup)
          raw_text(markup).lines.map { |line| line.chomp.length }.max || 0
        end

        def height(markup)
          raw_text(markup).lines.length
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

        def slice(markup, range, safe: true)
          absolute_start, absolute_stop = absolute_start_stop(range,
                                                              length(markup))
          # @todo only return hashes before start (and only if safe)
          return markup.grep(Hash) if absolute_stop < absolute_start

          i = 0
          markup.map do |token|
            if token.is_a?(Hash)
              if (absolute_start..absolute_stop).include?(i) ||
                 (safe && i < absolute_start)
                next token
              end

              next
            end

            token_start = i
            token_stop = i + token.length - 1
            i += token.length
            next if token_start > absolute_stop
            next if token_stop < absolute_start

            if token_start < absolute_start
              relative_start = absolute_start - token_start
            end
            if token_stop > absolute_stop
              relative_stop = absolute_stop - token_start
            end
            token[relative_start..relative_stop]
          end.compact
        end

        def scale(markup, max_width)
          lines = lines(markup, safe: false)
          lines.each_with_index do |line, i|
            line.replace(rstrip(line))
            next if length(line) <= max_width

            start_new =
              raw_text(line).rindex(/(?<!\s)\s/, max_width) || max_width
            old_line = slice(line, ...start_new, safe: false)
            new_line = slice(line, start_new.., safe: false)
            new_line = lstrip(new_line)
            line.replace(old_line)
            lines.insert(i + 1, new_line)
          end
          new_markup = lines.map { |line| line + [$/] }.flatten
          chomp(markup) == markup ? chomp(new_markup) : new_markup
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
          # rubocop:disable Style/ComparableClamp (clamp doesn't work when min == max)
          start = [[start, 0].max, length - 1].min
          stop = [[stop, 0].max, length - 1].min
          # rubocop:enable Style/ComparableClamp
          [start, stop]
        end
      end
    end
  end
end
