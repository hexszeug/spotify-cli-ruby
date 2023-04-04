# frozen_string_literal: true

module Main
  module Display
    class Error
      def initialize(screen_message)
        # @todo not here somehow delete loading msgs that got crashed by error
        @screen_message = screen_message
      end

      def generate(_width)
        # @todo explain Spotify::SpotifyError subclasses
        error = @screen_message.content
        <<~TEXT
          $r#{error.full_message.gsub(/\e\[[;\d]*m/, '')}
        TEXT
      end
    end
  end
end
