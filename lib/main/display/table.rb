# frozen_string_literal: true

module Main
  module Display
    module Display
      class Table
        def initialize(*columns)
          @columns = columns.map do |col|
            if col.is_a?(Integer)
              col
            else
              {
                min: 0,
                fraction: 1
              }.merge(col)
            end
          end
          @rows = []
        end

        def add_row(*cells)
          unless cells.length == @columns.length
            raise ArgumentError, 'wrong cell count'
          end

          @rows += cells
        end

        def generate(width)
          column_widths = calculate_column_widths(width)
          @rows.map { |row| generate_row(row, column_widths) }.join("\n")
        end

        private

        def calculate_column_widths(total_width)
          widths = @columns.dup
          loop do
            fixed_width = widths.grep(Integer).sum
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
          # @todo implement (with dynamic row height etc)
        end
      end
    end
  end
end
