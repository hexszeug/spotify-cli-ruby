# frozen_string_literal: true

module Spotify
  module Auth
    module Token
      TOKEN_PATH = "#{Spotify::CONFIG_DIR}/token.json".freeze

      class NoTokenError < SpotifyError
      end

      # superclass for token parse errors
      class TokenParseError < SpotifyError
      end

      class MalformedTokenError < TokenParseError
      end

      class MissingAccessTokenError < TokenParseError
      end

      class MissingExpirationTimeError < TokenParseError
      end

      class MissingRefreshTokenError < TokenParseError
      end

      class << self
        def get
          @token
        end

        def access_token
          raise NoTokenError unless @token

          @token[:access_token]
        end

        def refresh_token
          raise NoTokenError unless @token

          @token[:refresh_token]
        end

        # returns:
        # - token
        #
        # raises:
        # - NoTokenError
        def save
          raise NoTokenError unless @token

          token_json = JSON.pretty_generate(@token)
          FileUtils.mkpath(File.dirname(TOKEN_PATH))
          File.write TOKEN_PATH, "#{token_json}\n"
          @token
        end

        # returns:
        # - token
        #
        # raises:
        # - NoTokenError
        # - MalformedTokenError
        # - MissingAccessTokenError
        # - MissingExpirationTimeError
        # - MissingRefreshTokenError
        def load
          raise NoTokenError unless File.file? TOKEN_PATH

          set(JSON.parse(File.read(TOKEN_PATH), symbolize_names: true))
          refresh if @token[:expires_at] <= Time.now.to_i
        rescue JSON::JSONError
          raise MalformedTokenError
        end

        # returns:
        # - token
        # - Promise (when called with block)
        #
        # resolves:
        # - token
        #
        # raises / resolves to error:
        # - NoTokenError (always raised. even when called with block)
        # - MalformedTokenError
        # - MissingAccessTokenError
        # - MissingExpirationTimeError
        # - MissingRefreshTokenError
        # - Auth::TokenFetcher::ParseError
        # - Auth::TokenFetcher::TokenDeniedError
        # - Request::RequestError
        #
        # TODO: delete token when TokenDenied tells to do so
        def refresh(&)
          raise NoTokenError unless @token

          return set(Auth::TokenFetcher.fetch) unless block_given?

          promise = Spotify::Promise.new(&)
          fetch_promise =
            Auth::TokenFetcher.fetch do |token|
              set(token)
            rescue TokenParseError => e
              promise.resolve_error(e)
            else
              promise.resolve @token
            end.error do |error|
              promise.resolve_error(error)
            end
          promise.on_cancel { fetch_promise.cancel }
        end

        # returns:
        # - token
        #
        # raises:
        # - MalformedTokenError
        # - MissingAccessTokenError
        # - MissingExpirationTimeError
        # - MissingRefreshTokenError
        def set(token)
          raise MalformedTokenError unless token.instance_of?(Hash)
          raise MissingAccessTokenError unless token[:access_token]
          raise MissingRefreshTokenError unless token[:refresh_token] || @token
          unless token[:expires_at] || token[:expires_in]
            raise MissingExpirationTimeError
          end

          token[:refresh_token] ||= @token[:refresh_token]
          @token = token
          flatten
          normalize_expiration_time
          deep_freeze
        end

        private

        ALLOWED_PAIRS = {
          access_token: String,
          refresh_token: String,
          expires_in: Integer,
          expires_at: Integer
        }.freeze

        def flatten
          @token.delete_if do |key, value|
            !ALLOWED_PAIRS.key?(key) || !value.instance_of?(ALLOWED_PAIRS[key])
          end
        end

        def normalize_expiration_time
          return unless @token[:expires_in]

          @token[:expires_at] ||= Time.now.to_i + @token[:expires_in]
          @token.delete(:expires_in)
        end

        def deep_freeze
          @token.each_value(&:freeze)
          @token.freeze
        end
      end
    end
  end
end
