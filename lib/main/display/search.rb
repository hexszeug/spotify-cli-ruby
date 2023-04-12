# frozen_string_literal: true

module Main
  module Display
    class Search
      include Names

      def initialize(screen_message)
        # @todo display other search results
        search = screen_message.content
        @lists = search[:results].map do |key, value|
          case key
          when :tracks
            Display::Track::List.new(
              value[:items],
              title: "$*Searched for '#{escape(search[:q])}' in tracks$*"
            ) { screen_message.touch }
          when :albums
            Display::Album::List.new(
              value[:items],
              title: "$*Searched for '#{escape(search[:q])}' in albums$*"
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
