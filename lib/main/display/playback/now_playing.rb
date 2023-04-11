# frozen_string_literal: true

module Main
  module Display
    module Playback
      class NowPlaying
        include Names

        def initialize(screen_message)
          @screen_message = screen_message
          @promise = Spotify::API::Player.get_playback_state do |state|
            @playback = state
            @screen_message.touch
          end.error do |e|
            @screen_message.replace(e, type: Display::Error)
          end
        end

        def delete
          @promise.cancel
        end

        def generate(_width)
          return <<~TEXT if @playback.nil?
            Loading.$~.
          TEXT

          return <<~TEXT if @playback[:item].nil?
            No track playing.
          TEXT

          track = @playback[:item]
          <<~TEXT
            Now playing: $*#{track(track)}$* by $%$*#{artists(track[:artists])}$*$%
          TEXT
        end
      end
    end
  end
end
