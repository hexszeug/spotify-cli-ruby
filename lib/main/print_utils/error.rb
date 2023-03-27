# frozen_string_literal: true

module Main
  module PrintUtils
    class Error < UI::ScreenMessage
      private

      def update_content(error)
        # @todo explain Spotify::SpotifyError subclasses
        super(<<~TEXT)
          $r#{error.full_message.gsub(/\e\[[;\d]*m/, '')}
        TEXT
      end
    end
  end
end
