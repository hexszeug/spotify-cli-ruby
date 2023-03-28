# frozen_string_literal: true

module Main
  module Display
    module Entities
      class SearchResults < UI::ScreenMessage
        def context_updated
          @changed = true
        end

        private

        def update_content(search)
          @q = search[:q]
          @type = search[:type]
          @items = search[:items]
          Context.register(@items.map { |item| item[:uri] })
        end

        def generate_markup(max_length)
          # @todo display results in table
          markup = <<~TEXT
            Searched #{@type} for '#{@q}'
            #{@items.map { |v| "#{v[:name]} $%(#{Context.hook(v[:uri], self)})$%" }.join(' * ')}
          TEXT
          # @todo remove redundant markup parsing (when fixed in ScreenMessage)
          markup.split(/\r\n|\n/).flat_map do |line|
            line_break(UI::Markup.parse(line), max_length)
          end
        end
      end
    end
  end
end
