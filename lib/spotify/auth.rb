# frozen_string_literal: true

require 'securerandom'

module Spotify
  module Auth
    APP_ID = '4388096316894b88a147b53559d0c14a'
    APP_SECRET = '77f2373853974699824602358ecdf9bd'

    PROMPT_URL = 'https://accounts.spotify.com/authorize/'
    REDIRECT_URL = 'http://localhost:8888/callback/'
    TOKEN_URL = 'https://accounts.spotify.com/api/token/'

    class LoginError < Spotify::SpotifyError
    end

    class << self
      LOGIN_TIMEOUT_SEC = 5 * 60

      def login
        return unless block_given?

        timeout_thread = Thread.new do
          Thread.current.name = 'login/timeout'
          sleep LOGIN_TIMEOUT_SEC
          CodeServer.stop
        end
        state = SecureRandom.hex 16
        CodeServer.start(state) do |code_or_error|
          if code_or_error.instance_of? StandardError
            timeout_thread.kill
            yield code_or_error
          else
            token = TokenFetcher.fetch(code: code_or_error)
            Token.set_token(token)
            timeout_thread.kill
            Thread.new { 
              Thread.current.name = 'login/return'
              yield
            }
          end
        end
        Prompt.open(state)
      rescue CodeServer::OpenServerError => e
        timeout_thread.kill
        yield e
      rescue Prompt::OpenPromptError => e
        CodeServer.stop
        timeout_thread.kill
        yield e
      end
    end
  end
end

require_relative 'auth/token'
require_relative 'auth/prompt'
require_relative 'auth/code_server'
require_relative 'auth/token_fetcher'
