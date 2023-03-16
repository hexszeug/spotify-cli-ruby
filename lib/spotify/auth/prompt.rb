# frozen_string_literal: true

require 'launchy'

module Spotify
  module Auth
    module Prompt
      class OpenPromptError < Auth::LoginError
      end

      class << self
        PROMPT_QUERY = {
          client_id: APP_ID,
          response_type: 'code',
          redirect_uri: Auth::REDIRECT_URL,
          show_dialog: true,
          scope: %w[
            ugc-image-upload
            user-read-playback-state
            user-modify-playback-state
            playlist-read-private
            user-follow-modify
            playlist-read-collaborative
            user-follow-read
            user-read-currently-playing
            user-read-playback-position
            user-library-modify
            playlist-modify-private
            playlist-modify-public
            user-read-email
            user-top-read
            user-read-recently-played
            user-read-private
            user-library-read
          ].join(' ')
        }.freeze

        # raises:
        # - OpenPromptError when failed to open prompt
        def open(state)
          uri = URI(Auth::PROMPT_URL)
          uri.query = URI.encode_www_form(PROMPT_QUERY.merge(state:))
          Launchy.open(uri.to_s)
        rescue Launchy::Error
          raise OpenPromptError
        end
      end
    end
  end
end
