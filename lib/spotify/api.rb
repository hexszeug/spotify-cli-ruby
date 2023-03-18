# frozen_string_literal: true

require 'uri'

module Spotify
  module API
    class Error < SpotifyError
      attr_reader :body

      def initialize(body)
        super()
        @body = body
      end
    end

    class ServerError < Error
    end

    class BadResponse < Error
      def initialize(code)
        super({ status: code, message: 'Bad Response.' })
      end
    end

    class BadRequest < Error
    end

    class Unauthorized < Error
    end

    class Forbidden < Error
    end

    class NotFound < Error
    end

    class TooManyRequests < Error
      attr_reader :retry_after

      def initialize(body, retry_after)
        super(body)
        @retry_after = retry_after
      end
    end

    class InternalServerError < ServerError
    end

    class BadGateway < ServerError
    end

    class ServiceUnavailable < ServerError
    end

    Error::CODES = {
      '400' => BadRequest,
      '401' => Unauthorized,
      '403' => Forbidden,
      '404' => NotFound,
      '429' => TooManyRequests,
      '500' => InternalServerError,
      '502' => BadGateway,
      '503' => ServiceUnavailable
    }.freeze

    class << self
      BASE_URL = 'https://api.spotify.com/v1'
      DEFAULT_RETRIES = 2

      ##
      # @param endpoint [String] the rest endpoint starting with a slash
      # @param method [Symbol] *(optional)* one of :get, :post, :put, :delete
      # @param query [Hash] *(optional)*
      # @param body [Hash] [String] *(optional)*
      #   if Hash gets converted to json string
      #
      # @return [Hash] response data
      # @return [true] successful call
      # @return [Promise] *(when called with block)*
      #
      # @raise [Auth::Token::NoTokenError]
      # @raise [Error] superclass
      # @raise [BadResponse]
      # @raise [BadRequest]
      # @raise [Unauthorized]
      # @raise [Forbidden]
      # @raise [NotFound]
      # @raise [TooManyRequests]
      # @raise [InternalServerError]
      # @raise [BadGateway]
      # @raise [ServiceUnavailable]
      # @raise [Request::RequestError] superclass
      # @raise [Request::ConnectionError]
      # @raise [Request::ParsingError]
      # @raise [Request::TimeoutError]
      # @raise [Auth::Token::NoTokenError]
      # @raise [Auth::Token::TokenParseError] superclass
      # @raise [Auth::Token::MalformedTokenError]
      # @raise [Auth::Token::MissingAccessTokenError]
      # @raise [Auth::Token::MissingExpirationTimeError]
      # @raise [Auth::Token::MissingRefreshTokenError]
      # @raise [Auth::TokenFetcher::TokenFetchError] superclass
      # @raise [Auth::TokenFetcher::ParseError]
      # @raise [Auth::TokenFetcher::TokenDeniedError]
      def request(endpoint, method = :get, query: {}, header: {}, body: nil, &)
        promise = Promise.new(&) if block_given?
        begin
          args = make_request_args(endpoint, method, query, header, body)
        rescue Auth::Token::NoTokenError => e
          raise unless promise

          promise.fail(e)
          return promise
        end
        block_given? ? async_request(args, promise:) : sync_request(args)
      end

      private

      def make_request_args(endpoint, method, query, header, body)
        uri = URI(BASE_URL + endpoint)
        uri.query = URI.encode_www_form(query)
        header[:Authorization] = "Bearer #{Auth::Token.access_token}"
        header[:'Content-Type'] ||= 'application/json' if body
        body = JSON.generate(body) if body.is_a?(Hash)
        [uri, method, header, body]
      end

      def sync_request(args)
        DEFAULT_RETRIES.downto(0) do |retries|
          break receive(Request.http(*args))
        rescue Unauthorized
          raise unless Auth::Token.expired?

          Auth::Token.refresh
          redo
        rescue TooManyRequests => e
          raise if retries.zero?

          sleep e.retry_after
        rescue ServerError
          raise if retries.zero?
        end
      end

      def async_request(args, promise:, retries: DEFAULT_RETRIES)
        request_promise =
          Request.http(*args) do |res|
            res = receive(res)
          rescue Unauthorized
            raise unless Auth::Token.expired?

            refresh_promise = Auth::Token.refresh do
              async_request(args, promise:, retries:)
            end.error do |error|
              promise.fail(error)
            end
            promise.on_cancel { refresh_promise.cancel }
          rescue TooManyRequests => e
            thread = Thread.current
            promise.on_cancel { thread.kill }
            sleep e.retry_after
            async_request(args, promise:, retries: retries - 1)
          rescue ServerError
            raise if retries.zero?

            async_request(args, promise:, retries: retries - 1)
          else
            promise.resolve(res)
          end.error do |request_error|
            promise.fail(request_error)
          end
        promise.on_cancel { request_promise.cancel }
      end

      def receive(res)
        data = read_body(res.body)
        case (code = res.code)
        when '200', '201', '202', '204' then data
        when /^[45]/
          raise BadResponse(res.code) unless data && Error::CODES.key?(code)

          if Error::CODES[code] == TooManyRequests
            raise(
              TooManyRequests.new(data, res['Retry-After'].to_i)
            )
          end

          raise Error::CODES[code], data
        else
          raise BadResponse
        end
      end

      def read_body(body)
        begin
          body = JSON.parse(body, symbolize_names: true)
        rescue JSON::JSONError
          body = nil
        end
        return if body.nil?

        # @todo create spotify objects (user, album, song, playlist, etc.)
        body
      end
    end
  end
end

require_relative 'api/users'
