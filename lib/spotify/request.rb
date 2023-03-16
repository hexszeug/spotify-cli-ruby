# frozen_string_literal: true

require 'net/http'

module Spotify
  module Request
    # TODO: properly cache results
    # TODO: use persistent tcp connection

    # superclass for request errors
    class RequestError < SpotifyError
      attr_reader :uri, :method, :header, :body

      def initialize(uri, method, header, body, msg = nil)
        super(msg) if msg
        @uri = uri
        @method = method
        @header = header
        @body = body
      end
    end

    class TimeoutError < RequestError
    end

    class CancelError < RequestError
    end

    class ConnectionError < RequestError
    end

    class ParsingError < RequestError
    end

    class << self
      DEFAULT_TIMEOUT = 10

      # returns:
      # - Net::HTTPResponse
      # - Promise (when called with block)
      #
      # resolves:
      # - Net::HTTPResponse
      #
      # raises / resolves to errors:
      # - TimeoutError
      # - ConnectionError
      # - ParsingError
      #
      # resolves to errors:
      # - CancelError
      def http(
        uri,
        method,
        header = {},
        body = nil,
        timeout: DEFAULT_TIMEOUT,
        &
      )
        uri = URI(uri) if uri.is_a?(String)
        unless uri.is_a?(URI::HTTP)
          raise ArgumentError,
                "#{uri} is not an http uri"
        end

        name = "request/#{method.to_s.upcase} request to #{uri}"
        if block_given?
          promise = Spotify::Promise.new(&)
          thread =
            Thread.new do
              Thread.current.name = name
              res = http(uri, method, header, body, timeout:)
            rescue RequestError => e
              promise.resolve_error(e)
            else
              promise.resolve(res)
            end
          return promise.on_cancel do
                   thread.raise CancelError.new uri, method, header, body
                 end
        end
        begin
          timeout_thread =
            Thread.new(Thread.current) do |request_thread|
              Thread.current.name = "#{name} (timeout)"
              sleep timeout
              request_thread.raise TimeoutError.new uri, method, header, body
            end
          res = sync_http_request(uri, method, header, body)
        ensure
          timeout_thread.kill
        end
        res
      end

      private

      def sync_http_request(uri, method, header, body)
        req_class =
          case method.downcase
          when :get
            Net::HTTP::Get
          when :post
            Net::HTTP::Post
          when :put
            Net::HTTP::Put
          when :delete
            Net::HTTP::Delete
          when :head, :options, :trace, :patch
            raise ArgumentError, "http method `#{method}' is not supported"
          else
            raise ArgumentError, "method `#{method}' isn't an http method"
          end
        req = req_class.new uri, header
        req.delete 'user-agent'
        begin
          res =
            Net::HTTP.start(
              uri.hostname,
              uri.port,
              use_ssl: uri.instance_of?(URI::HTTPS)
            ) { |http_connection| http_connection.request req, body }
          res.read_body
        rescue SystemCallError, IOError, OpenSSL::SSL::SSLError => e
          raise ConnectionError.new uri, method, header, body, e.message
        rescue Net::HTTPBadResponse, Net::HTTPUnknownResponse => e
          raise ParsingError.new uri, method, header, body, e.message
        rescue Timeout::Error => e
          raise TimeoutError.new uri, method, header, body, e.message
        end
        res
      end
    end
  end
end
