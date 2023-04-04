# frozen_string_literal: true

module Main
  module DefCmd
    class Play
      # @todo play track in context
      # @todo set device if non is selected by default by spotify
      include Command
      include UI::PrintUtils

      def initialize(dispatcher)
        dispatcher.register(
          literal('play').executes do
            resume
          end.then(
            Context::URIArgument.new(
              :uris,
              allow_types: %i[track episode]
            ).executes do |ctx|
              play_tracks(ctx[:uris])
            end
          ).then(
            Context::URIArgument.new(
              :ctx_uris,
              allow_types: %i[artist album playlist show]
            ).executes do |ctx|
              play_context(ctx[:ctx_uris][0])
            end
          )
        )
      end

      private

      def resume
        Spotify::API::Player.start_resume_playback do
          print('@todo print playback state')
        end.error do |e|
          print(e, type: Display::Error)
        end
      end

      def play_tracks(uris)
        Spotify::API::Player.start_resume_playback(uris:) do
          print('@todo print playback state')
        end.error do |e|
          print(e, type: Display::Error)
        end
      end

      def play_context(context_uri, _offset = nil)
        # @todo implement offset
        Spotify::API::Player.start_resume_playback(context_uri:) do
          print('@todo print playback state')
        end.error do |e|
          print(e, type: Display::Error)
        end
      end
    end
  end
end
