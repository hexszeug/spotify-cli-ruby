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

      def search(q, type: %i[track artist])
        print[:search] = <<~TEXT
          Searching for '#{q}'.$~.
        TEXT
        Spotify::API::Search.search_for_item(
          q:, type:, pagination: Spotify::API::Pagination.new
        ) do |page|
          print[:search] += <<~TEXT
            $*$_Serach results for '#{q}':$*$_
          TEXT
          page.each do |key, value|
            search_obj = {
              q:,
              type: key,
              items: value[:items]
            }
            print(search_obj, type: Display::Entities::SearchResults)
          end
        end.error do |e|
          print(e, type: Display::Error)
        end
      end
    end
  end
end
