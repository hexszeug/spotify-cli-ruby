# frozen_string_literal: true

module Main
  module DefCmd
    class TopItems
      include Command
      include UI::PrintUtils

      def initialize(dispatcher)
        dispatcher.register(
          literal('top').then(
            literal('artists').executes do
              top_items(:artists)
            end
          ).then(
            literal('tracks').executes do
              top_items(:tracks)
            end
          )
        )
      end

      private

      def top_items(type)
        print[type] = <<~TEXT
          Fetching top #{type}.$~.
        TEXT
        Spotify::API::Users.get_users_top_items(
          type:,
          pagination: Spotify::API::Pagination.new
        ) do |page|
          print[type] += <<~TEXT
            $*Your top #{type}$*
            #{page[:items].map { |v| v[:name] }.join("\n")}
          TEXT
        end.error do |e|
          print(e, type: Display::Error)
        end
      end
    end
  end
end
