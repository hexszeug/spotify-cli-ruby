# frozen_string_literal: true

module Main
  module DefCmd
    class TopItems
      include Command
      include Utils

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
        Spotify::API::Users.get_users_top_items(
          type:,
          pagination: Spotify::API::Pagination.new
        ) do |page|
          UI.print_raw <<~TEXT
            Your top #{type}
            #{page[:items].map { |v| v[:name] }.join("\n")}
          TEXT
        end.error do |e|
          UI.print_raw explain_error(e)
        end
      end
    end
  end
end
