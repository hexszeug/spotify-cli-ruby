# frozen_string_literal: true

module Main
  module DefCmd
    class Search
      include Command
      include UI::PrintUtils
      # @todo implement useful search (not 1000 results etc.)

      def initialize(dispatcher)
        dispatcher.register(
          literal('search').then(
            Arguments::GreedyString.new(:q).executes do |ctx|
              search(ctx[:q])
            end
          )
        )
      end

      private

      def search(q, type: %i[track])
        display_q = q.gsub('$', '$$')
        screen_message = print <<~TEXT
          Searching for '#{display_q}'.$~.
        TEXT
        Spotify::API::Search.search_for_item(
          q:, type:, pagination: Spotify::API::Pagination.new(limit: 100)
        ) do |results|
          screen_message.replace({ q:, results: }, type: Display::Search)
        end.error do |e|
          screen_message.replace(e, type: Display::Error)
        end
      end
    end
  end
end
