# frozen_string_literal: true

module Main
  module DefCmd
    class Details
      include Command
      include UI::PrintUtils

      def initialize(dispatcher)
        dispatcher.register(
          literal('details').then(
            Context::URIArgument.new(
              :album_uri,
              allow_types: %i[album],
              allow_multiple: false
            ).executes do |ctx|
              album(ctx[:album_uri])
            end
          )
        )
      end

      private

      def album(uri)
        screen_message = print('Loading.$~.')
        album_id = uri.split(':').last
        Spotify::API::Albums.get_album(id: album_id) do |album|
          album[:tracks] =
            Spotify::API::Albums.get_album_tracks(
              album_id:,
              pagination: Spotify::API::Pagination.new
            )[:items]
          screen_message.replace(album, type: Display::Album::Details)
        end
      end
    end
  end
end
