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
        screen_message = print <<~TEXT
          Searching for '#{q}'.$~.
        TEXT
        Spotify::API::Search.search_for_item(
          q:, type:, pagination: Spotify::API::Pagination.new
        ) do |page|
          screen_message.replace(<<~TEXT)
            $*$_Serach results for '#{q}':$*$_
          TEXT
          page.each do |key, value|
            case key
            when :tracks
              list = {
                title: "Searched for '#{q.gsub('$', '$$')}' in #{key}",
                tracks: value[:items]
              }
              print(list, type: Display::Track::List)
            end
          end
        end.error do |e|
          screen_message.replace(e, type: Display::Error)
        end
      end
    end
  end
end
