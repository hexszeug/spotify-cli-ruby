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
        screen_message = print <<~TEXT
          Fetching top #{type}.$~.
        TEXT
        Spotify::API::Users.get_users_top_items(
          type:,
          pagination: Spotify::API::Pagination.new
        ) do |page|
          screen_message.replace(<<~TEXT)
            $*Your top #{type}$*
            #{page[:items].map { |v| v[:name] }.join("\n")}
          TEXT
        end.error do |e|
          screen_message.replace(e, type: Display::Error)
        end
      end
    end
  end
end
