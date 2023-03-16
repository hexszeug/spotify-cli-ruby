# frozen_string_literal: true

require 'net/http'

module Spotify
  module Request
    # TODO: refactor
    # TODO: properly cache results
    # TODO: use persistent tcp connection
    class << self
      DEFAULT_TIMEOUT = 10

      def http_request(
        uri,
        method,
        header = {},
        body = nil,
        timeout: DEFAULT_TIMEOUT
      )
        name = "request/#{method.to_s.upcase} request to #{uri}"
        if block_given?
          thread =
            Thread.new do
              Thread.current.name = name
              res = http_request(uri, method, header, body, timeout:)
            rescue RequestError => e
              yield e
            else
              yield res
            end
          return proc { thread.raise CancelError.new uri, method, header, body }
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
              use_ssl: uri.scheme == 'https'
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
    end
  end
end
