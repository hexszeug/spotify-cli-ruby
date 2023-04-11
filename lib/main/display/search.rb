# frozen_string_literal: true

module Main
  module Display
    class Search
      include Names

      def initialize(screen_message)
        # @todo display other search results than tracks
        search = screen_message.content
        @lists = search[:results].map do |key, value|
          case key
          when :tracks
            Display::Track::List.new(
              value[:items],
              title: "Searched for '#{escape(search[:q])}' in #{key}"
            ) { screen_message.touch }
          end
        end
      end

      def delete
        @lists.each(&:delete)
      end

      def generate(width)
        @lists.map do |list|
          list.generate(width)
        end.join("\n")
      end
    end
  end
end
