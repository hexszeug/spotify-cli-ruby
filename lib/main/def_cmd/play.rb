# frozen_string_literal: true

module Main
  module DefCmd
    class Play
      # @todo set device if non is selected by default by spotify
      include Command
      include UI::PrintUtils

      def initialize(dispatcher)
        dispatcher.register(
          literal('play').executes do
            resume
          end.then(
            Context::URIArgument.new(
              :tracks,
              allow_types: %i[track episode],
              allow_mixed_types: false
            ).executes do |ctx|
              play_tracks(ctx[:tracks])
            end
          ).then(
            Context::URIArgument.new(
              :track,
              allow_types: %i[track episode],
              allow_multiple: false,
              with_context: true
            ).executes do |ctx|
              track = ctx[:track]
              if track[:context].nil?
                play_tracks([track[:uri]])
              else
                play_context(track[:context], track[:uri])
              end
            end
          ).then(
            Context::URIArgument.new(
              :context,
              allow_types: %i[artist album playlist show],
              allow_multiple: false
            ).executes do |ctx|
              play_context(ctx[:context])
            end.then(
              literal('at').then(
                Arguments::Integer.new(:position).executes do |ctx|
                  play_context(ctx[:context], ctx[:position] - 1)
                end
              )
            )
          )
        )
      end

      private

      def resume
        Spotify::API::Player.start_resume_playback do
          print(type: Display::Playback::NowPlaying)
        end.error do |e|
          print e, type: Display::Error
        end
      end

      def play_tracks(uris)
        Spotify::API::Player.start_resume_playback(uris:) do
          print(type: Display::Playback::NowPlaying)
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
          print(type: Display::Playback::NowPlaying)
        end.error do |e|
          print e, type: Display::Error
        end
      end
    end
  end
end
