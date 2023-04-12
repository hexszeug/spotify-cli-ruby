# frozen_string_literal: true

module Main
  module Display
    module Playback
      class NowPlaying
        include Names

        def initialize(screen_message)
          @screen_message = screen_message
          @promise = Spotify::API::Player.get_playback_state do |state|
            if (context = state[:context])
              state[:context] = fetch_context(context)
            end
            @playback = state
            @screen_message.touch
          rescue Spotify::SpotifyError => e
            @promise.fail(e)
          end.error do |e|
            @promise = nil
            @screen_message.replace(e, type: Display::Error)
          end
        end

        def context_updated
          @screen_message.touch
        end

        def delete
          @promise&.cancel
        end

        def generate(_width)
          return <<~TEXT if @playback.nil?
            Loading.$~.
          TEXT

          if (track = @playback[:item])
            <<~TEXT
              Now playing: $*#{track(track)}$* by $*#{artists(track[:artists])}$*
            TEXT
          elsif (context = @playback[:context])
            case context[:type]
            when 'artist' then <<~TEXT
              Now playing: Top songs of $*#{artist(context)}$*
            TEXT
            when 'playlist' then <<~TEXT
              Now playing: Playlist $*#{playlist(context)}$* by $*#{user(context[:owner])}$*
            TEXT
            when 'album' then <<~TEXT
              Now playing: Album $*#{album(context)}$* by $*#{artists(context[:artists])}$*
            TEXT
            else <<~TEXT
              Now playing: Playback type #{escape(context[:type])} is not supported.
            TEXT
            end
          else
            <<~TEXT
              No track playing.
            TEXT
          end
        end

        private

        def fetch_context(context)
          # @todo fetch other contexts
          type = context[:type]
          uri = context[:uri]
          id = uri.split(':').last
          context.merge(
            case type
            when 'album' then Spotify::API::Albums.get_album(id:)
            when 'playlist'
              Spotify::API::Playlists.get_playlist(
                playlist_id: id,
                fields: Spotify::API::Fields.new(
                  {
                    name: true,
                    owner: {
                      display_name: true
                    }
                  }
                )
              )
            else context
            end
          )
        end
      end
    end
  end
end
