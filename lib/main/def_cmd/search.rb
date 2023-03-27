# frozen_string_literal: true

module Main
  module DefCmd
    class Search
      include Command
      include PrintUtils
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
            #{
              page.keys.map do |key|
                <<~TYPE
                  $*#{key.capitalize}:$*
                  #{page[key][:items].map { |v| v[:name] }.join(' * ')}
                TYPE
              end.join("\n")
            }
          TEXT
        end.error do |e|
          error(e)
        end
      end
    end
  end
end
