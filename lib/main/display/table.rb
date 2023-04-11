# frozen_string_literal: true

module Main
  module Display
    class Table
      ##
      # A column is described by a hash
      # containing the following options:
      # - width: [Hash] or [Integer]
      #   Hash includes a fraction and a min value
      # - align: `:left`, `:center` or `:right`
      # - (vertical_align: `:top`, `:center` or `:bottom`)
      # - overflow: `:hidden`, `:tripple_dot` or (`:line_break`)
      #
      # () = does nothing
      #
      # @param column... [Hash] a column hash as described above
      def initialize(*columns, gap: 1, vertical_gap: 1)
        @gap = gap
        @vertical_gap = vertical_gap

        @columns = columns.each do |col|
          if (width = col[:width]).is_a?(Integer)
            col[:width] = [col[:width], 0].max
          else
            col[:width] = {
              min: 0,
              fraction: 1
            }
            col[:width].update(width) if width.is_a?(Hash)
          end
          col[:align] = :left unless %i[left center right].include?(col[:align])
          unless %i[hidden tripple_dot].include?(col[:overflow])
            col[:overflow] = :hidden
          end
        end
        @rows = []
      end

      def add_row(*cells)
        unless cells.length == @columns.length
          raise ArgumentError, 'wrong cell count'
        end

        @rows.push(cells.map { |cell| UI::Markup.new(cell) })
      end

      def generate(width)
        column_widths = calculate_column_widths(width)
        @rows.map do |row|
          generate_row(row, column_widths)
        end.join("\n" * (@vertical_gap + 1))
      end

      private

      def calculate_column_widths(total_width)
        gaps = (@columns.length - 1) * @gap
        widths = @columns.map { |col| col[:width] }
        fraction = nil
        loop do
          fixed_width = widths.grep(Integer).sum + gaps
          fractions = widths.grep(Hash).map { |col| col[:fraction] }.sum
          fraction = [(total_width - fixed_width) / fractions, 0].max
          index = widths.index do |col|
            col.is_a?(Hash) && col[:min] > col[:fraction] * fraction
          end
          break if index.nil?

          widths[index] = widths[index][:min]
        end
        widths.map do |col|
          col.is_a?(Integer) ? col : col[:fraction] * fraction
        end
      end

      def generate_row(row, column_widths)
        # @todo implement multiline rows
        row.map.with_index do |cell, i|
          width = column_widths[i]
          if cell.width > width
            cell =
              case @columns[i][:overflow]
              when :hidden then cell[...width]
              when :tripple_dot
                width > 3 ? "#{cell[...(width - 3)]}..." : '.' * width
              end
          elsif cell.width < width
            m = width - cell.width
            cell =
              case @columns[i][:align]
              when :left then "#{cell}#{' ' * m}"
              when :right then "#{' ' * m}#{cell}"
              when :center
                "#{' ' * (m / 2)}#{cell}#{' ' * (m - (m / 2))}"
              end
          end
          cell
        end.join(' ' * @gap)
      end
    end
  end
end
