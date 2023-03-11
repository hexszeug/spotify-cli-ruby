require_relative "spotify"

require "net/http"

#TODO
# properly cache results
# use persistent tcp connection

module Spotify
    module Request
        DEFAULT_TIMEOUT = 10

        def Request.http_request(
            uri,
            method,
            header = {},
            body = nil,
            timeout: DEFAULT_TIMEOUT,
            &callback
        )
            name = "request/#{method.to_s.upcase} request to #{uri}"
            if callback
                thread =
                    Thread.new(callback) do |callback|
                        begin
                            res = http_request uri, method, header, body, timeout: timeout
                        rescue SpotifyError => e
                            callback.call e
                        else
                            callback.call res
                        end
                    end
                thread.name = name
                return proc { thread.raise CancelError.new uri, method, header, body }
            end
            begin
                timeout_thread =
                    Thread.new(timeout, Thread.current) do |timeout, thread|
                        sleep timeout
                        thread.raise TimeoutError.new uri, method, header, body
                    end
                timeout_thread.name = name + " (timeout)"
                res = sync_http_request(uri, method, header, body)
            ensure
                timeout_thread.kill
            end
            return res
        end

        def self.sync_http_request(uri, method, header, body)
            case method.downcase
            when :get
                req_class = Net::HTTP::Get
            when :post
                req_class = Net::HTTP::Post
            when :put
                req_class = Net::HTTP::Put
            when :delete
                req_class = Net::HTTP::Delete
            when :head, :options, :trace, :patch
                raise ArgumentError.new "http method `#{method}' is not supported"
            else
                raise ArgumentError.new "method `#{method}' isn't an http method"
            end
            req = req_class.new uri, header
            req.delete "user-agent"
            begin
                Net::HTTP.start(
                    uri.hostname,
                    uri.port,
                    use_ssl: uri.scheme == "https",
                ) { |http_connection| return http_connection.request req, body }
            rescue SystemCallError, IOError, OpenSSL::SSL::SSLError => e
                raise ConnectionError.new uri, method, header, body, e.message
            rescue Net::HTTPBadResponse, Net::HTTPUnknownResponse => e
                raise ParsingError.new uri, method, header, body, e.message
            rescue Timeout::Error => e
                raise TimeoutError.new uri, method, header, body, e.message
            end
        end
    end

    class RequestError < SpotifyError
        def initialize(uri, method, header, body, msg = nil)
            super msg if msg
            @uri = uri
            @method = method
            @header = header
            @body = body
        end

        attr_reader :uri
        attr_reader :method
        attr_reader :header
        attr_reader :body
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

#TODO remove testing script

if caller.length == 0
    cancel =
        Spotify::Request.http_request(
            URI("http://localhost:8888"),
            :get,
            timeout: 20,
        ) do |res|
            if res.is_a? Exception
                puts "exception = #{res.class}"
            else
                puts "response = #{res}"
            end
        end
    gets
    cancel.call
    sleep 10
end
