# frozen_string_literal: true

module Main
  module DefCmd
    class Search
      include Command
      include Utils

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
        Spotify::API::Search.search_for_item(
          q:, type:, pagination: Spotify::API::Pagination.new
        ) do |page|
          UI.print_raw <<~TEXT
            Serach results:
            #{
              page.keys.map do |key|
                <<~TYPE
                  #{key.capitalize}:
                  #{page[key][:items].map { |v| v[:name] }.join(' * ')}
                TYPE
              end.join("\n")
            }
          TEXT
        end.error do |e|
          UI.print_raw explain_error(e)
        end
      end
    end
  end
end
