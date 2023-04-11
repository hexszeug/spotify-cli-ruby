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

      def album(_uri)
        album = JSON.parse(File.read('test_album.json'), symbolize_names: true)
        print(album, type: Display::Album::Details)
      end
    end
  end
end
