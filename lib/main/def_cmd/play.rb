# frozen_string_literal: true

module Main
  module DefCmd
    class Play
      # @todo play albums, playlist, artists, etc.
      # @todo play track in context
      include Command
      include UI::PrintUtils

      def initialize(dispatcher)
        dispatcher.register(
          literal('play').executes do
            resume
          end.then(
            Context::URIArgument.new(
              :uris,
              allow_mixed_types: [:track],
              allow_mixed_contexts: false
            ).executes do |ctx|
              play_tracks(ctx[:uris])
            end
          )
        )
      end

      private

      def resume; end

      def play_tracks(uri_objs)
        uris = uri_objs.map { |uri| uri[:uri] }
        Spotify::API::Player.start_resume_playback(uris:) do
          print('@todo print playback state')
        end.error do |e|
          print(e, type: Display::Error)
        end
      end
    end
  end
end
