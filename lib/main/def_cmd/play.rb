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
              allow_types: %i[track episode],
              allow_mixed_types: false
            ).executes do |ctx|
              play_tracks(ctx[:uris])
            end
          ).then(
            Context::URIArgument.new(
              :context_uri,
              allow_types: %i[track episode],
              single_uri_with_context: true
            ).executes do |ctx|
              context = ctx[:context_uri]
              play_context(context[:context], context[:uri])
            end
          ).then(
            Context::URIArgument.new(
              :contexts,
              allow_types: %i[artist album playlist show]
            ).executes do |ctx|
              play_context(ctx[:contexts][0])
            end
          )
        )
      end

      private

      def resume
        Spotify::API::Player.start_resume_playback do
          print '@todo print playback state'
        end.error do |e|
          print e, type: Display::Error
        end
      end

      def play_tracks(uris)
        Spotify::API::Player.start_resume_playback(uris:) do
          print '@todo print playback state'
        end.error do |e|
          print e, type: Display::Error
        end
      end

      def play_context(context_uri, offset = nil)
        unless offset.nil?
          offset_uri = offset if offset.is_a?(String)
          offset_position = offset if offset.is_a?(Integer)
        end
        Spotify::API::Player.start_resume_playback(
          context_uri:,
          offset_position:,
          offset_uri:
        ) do
          print '@todo print playback state'
        end.error do |e|
          print e, type: Display::Error
        end
      end
    end
  end
end
