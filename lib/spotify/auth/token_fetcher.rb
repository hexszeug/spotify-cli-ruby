# frozen_string_literal: true

require 'uri'
require 'base64'

module Spotify
  module Auth
    module TokenFetcher
      # superclass for token fetch errors
      class TokenFetchError < SpotifyError
      end

      # raised when token endpoint return not parsable body
      class ParseError < TokenFetchError
      end

      # raised when token endpoint denies to request new / refresh token
      # for possible error_str see https://www.rfc-editor.org/rfc/rfc6749#section-5.2
      class TokenDeniedError < TokenFetchError
        attr_reader :error_str

        def initialize(error_str)
          super()
          @error_str = error_str
        end
      end

      class << self
        ENDPOINT_URI = URI(Auth::TOKEN_URL).freeze
        HEADER = {
          'Content-Type': 'application/x-www-form-urlencoded',
          Authorization:
                "Basic #{Base64.strict_encode64(
                  "#{Auth::APP_ID}:#{Auth::APP_SECRET}"
                )}"
        }.freeze
        CODE_BODY = {
          grant_type: 'authorization_code',
          redirect_uri: Auth::REDIRECT_URL
        }.freeze
        REFRESH_BODY = {
          grant_type: 'refresh_token'
        }.freeze

        # returns / yields:
        # - token
        #
        # raises / yield-raises:
        # - ParseError
        # - TokenFetchError
        # - Request::RequestError
        def fetch(code: nil)
          body = URI.encode_www_form(
            if code.nil?
              REFRESH_BODY.merge(refresh_token: Auth::Token.refresh_token)
            else
              CODE_BODY.merge(code:)
            end
          )
          if block_given?
            Spotify::Request.http_request(
              ENDPOINT_URI, :post, HEADER, body
            ) do |res|
              if res.is_a? Spotify::Request::RequestError
                yield res
              else
                begin
                  token = receive(res)
                rescue TokenFetchError => e
                  yield e
                else
                  yield token
                end
              end
            end
          else
            receive(
              Spotify::Request.http_request(ENDPOINT_URI, :post, HEADER, body)
            )
          end
        end

        private

        def receive(res)
          body = JSON.parse(res.body, symbolize_names: true)
          raise TokenDeniedError, body[:error] if body.key?(:error)

          body
        rescue JSON::JSONError
          raise ParseError
        end
      end
    end
  end
end
