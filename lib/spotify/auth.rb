require_relative "spotify.rb"

require "uri"
require "securerandom"

require "launchy"
require "webrick"

#TODO refactor "begin rescue" to make use of "ensure" more often and to use "rescue; raise" instead of "rescue => e; raise e"

module Spotify
    PROMPT_TIMEOUT_SEC = 5 * 60

    module URLs
        AUTH_PROPT = "https://accounts.spotify.com/authorize/"
        AUTH_REDIRECT = "http://localhost:8888/callback/"
    end

    module Token
        include WEBrick

        TOKEN_DIR = Dir.home + "/.spotify-cli-ruby"
        TOKEN_PATH = TOKEN_DIR + "/token.json"

        SUCCESS_HTML_PATH = Dir.pwd + "/static/success.html"
        ERROR_HTML_PATH = Dir.pwd + "/static/error.html"

        HTTP_SERVER_CONFIG = Config::HTTP.update(Logger: BasicLog.new(nil, 0))

        APP_ID = "4388096316894b88a147b53559d0c14a"
        APP_SECRET = "77f2373853974699824602358ecdf9bd"

        def Token.save_token
            return false unless @token
            begin
                token_json = JSON.pretty_generate @token
            rescue JSON::JSONError
                return false
            end
            Dir.mkdir TOKEN_DIR unless Dir.exist? TOKEN_DIR
            File.write TOKEN_PATH, token_json + "\n"
            return true
        end

        def Token.load_token
            return false unless File.file? TOKEN_PATH
            begin
                token_hash = JSON.parse File.read(TOKEN_PATH), symbolize_names: true
            rescue JSON::JSONError
                return false
            end
            return set_token token_hash
        end

        def Token.new_token(&callback)
            return false if @getting_token && Thread.current != @getting_token
            if callback
                @getting_token =
                    Thread.new callback do |callback|
                        begin
                            new_token
                        rescue OAuth2Error => e
                            callback.call e
                        end
                        callback.call nil
                    end
                @getting_token.name = "getting token: main"
                return true
            end
            @getting_token = true unless @getting_token
            begin
                set_token request_token get_code
            ensure
                @getting_token = false
            end
            return @token[:access_token].dup
        end

        def Token.cancel_new_token
            return unless @getting_token.is_a?(Thread) && @getting_token.alive?
            @getting_token.raise AuthManualCanceledError.new
        end

        def self.set_token(token_hash)
            return false unless token_hash.is_a? Hash
            token = token_hash.dup
            token.delete_if do |key|
                !%i[access_token refresh_token expires_in expires_at].include? key
            end
            unless token.key?(:access_token) && token[:access_token].is_a?(String)
                return false
            end
            unless token.key?(:refresh_token) && token[:refresh_token].is_a?(String)
                return false
            end
            if token.key?(:expires_at) && token[:expires_at].is_a?(Integer)
                token.delete :expires_in
                @token = token
                refresh_token if Time.now.to_i >= token[:expires_at]
                return true
            end
            unless token.key?(:expires_in) && token[:expires_in].is_a?(Integer)
                return false
            end
            token[:expires_at] = Time.now.to_i + token[:expires_in]
            token.delete :expires_in
            @token = token
            return true
        end

        #TODO split "get_code" in multiple methods for better code readability

        def self.get_code
            # generate state
            state = SecureRandom.hex 16

            # open prompt
            query =
                URI.encode_www_form(
                    {
                        client_id: APP_ID,
                        response_type: "code",
                        redirect_uri: Spotify::URLs::AUTH_REDIRECT,
                        state: state,
                        scope:
                            %w[
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
                            ] * " ",
                        show_dialog: true,
                    },
                )
            begin
                Launchy.open Spotify::URLs::AUTH_PROPT + "?" + query
            rescue Launchy::Error => e
                raise OpenUserPromptError.new e.message
            end

            # get response
            # start timeout thread
            timeout_thread =
                Thread.new(Thread.current) do |thread|
                    sleep PROMPT_TIMEOUT_SEC
                    thread.raise AuthTimeoutedError.new
                end
            timeout_thread.name = "getting token: timeout"

            # start code-server
            begin
                redirect_uri = URI(Spotify::URLs::AUTH_REDIRECT)
                hostname, port, path =
                    redirect_uri.hostname,
                    redirect_uri.port,
                    redirect_uri.path
                threads = []
                sockets = []
                Socket.tcp_server_loop(hostname, port) do |socket|
                    sockets.push socket
                    thread =
                        Thread.new(socket, Thread.current) do |socket, thread|
                            begin
                                req = HTTPRequest.new HTTP_SERVER_CONFIG
                                res = HTTPResponse.new HTTP_SERVER_CONFIG
                                req.parse socket
                                raise HTTPStatus::NoContent.new if req.path != path
                                query = req.query
                                unless query.key?("state")
                                    raise WrongOrMissingState.new "missing state"
                                end
                                unless query["state"] == state
                                    raise WrongOrMissingState.new "wrong state `#{query["state"]}'"
                                end
                                if query.key?("error")
                                    if query["error"] == "access_denied"
                                        raise UserDeniedAccessError.new
                                    end
                                    raise AuthSpotifyOrUserError.new query["error"]
                                end
                                raise MissingCodeError.new unless query.key?("code")
                                # code received
                                send_response res, socket
                                thread.raise ReceivedCodeSignal.new query["code"]
                            rescue HTTPStatus::EOFError
                                socket.close
                            rescue AuthReportableError => e
                                send_response res, socket, e
                                thread.raise e
                            rescue HTTPStatus::Status => status
                                send_response res, socket, status
                            end
                        end
                    threads.push thread
                    thread.name =
                        "getting token: code-server request no. #{threads.length}"
                end
            rescue SystemCallError => e
                timeout_thread.kill
                raise OpenCodeServerError.new e.message
            rescue AuthCanceledError => e
                timeout_thread.kill
                threads.each &:kill
                sockets.each &:close
                raise e
            rescue ReceivedCodeSignal => code
                timeout_thread.kill
                threads.each &:kill
                sockets.each &:close
                return code.to_s
            end
        end

        def self.send_response(res, socket, status = nil)
            return if socket.closed?
            if status
                res.status = status.code
                res.body = generate_error_page status if HTTPStatus.error? status.code
            else
                res.status = HTTPStatus::RC_OK
                res.body = generate_success_page
            end
            res.content_type =
                "text/html; charset=#{res.body.encoding.name}" if res.body
            res.keep_alive = false
            # force WEBrick to don't add server header
            res.setup_header
            res.header.delete "server"
            begin
                res.send_header socket
                res.send_body socket
            rescue Exception
            end
            socket.close
        end

        def self.generate_success_page
            unless File.exist? SUCCESS_HTML_PATH
                return "Done! You may close this tab now."
            end
            return File.read SUCCESS_HTML_PATH
        end

        def self.generate_error_page(error)
            unless File.exist? ERROR_HTML_PATH
                return "#{error.status} #{error.reason_phrase}"
            end
            page = File.read ERROR_HTML_PATH
            page.gsub! "$error_code", error.code.to_s
            page.gsub! "$error_name", error.reason_phrase
            page.gsub! "$error_message", error.message.sub("\n", "\\n")
            return page
        end

        def self.request_token(code)
        end

        def self.refresh_token
        end

        class ReceivedCodeSignal < Exception
            def initialize(code)
                @code = code
            end

            def to_s
                @code
            end
        end
    end

    class OAuth2Error < SpotifyError
    end

    class OpenUserPromptError < OAuth2Error
    end

    class OpenCodeServerError < OAuth2Error
    end

    class AuthReportableError < OAuth2Error
        def code
            WEBrick::HTTPStatus::RC_INTERNAL_SERVER_ERROR
        end

        def reason_phrase
            WEBrick::HTTPStatus.reason_phrase code
        end
    end

    class AuthSpotifyOrUserError < AuthReportableError
        def initialize(msg = "", real_msg: nil)
            super real_msg ? real_msg : "Spotify\u24c7 error message: `#{msg}'"
        end

        def code
            WEBrick::HTTPStatus::RC_BAD_REQUEST
        end
    end

    class UserDeniedAccessError < AuthSpotifyOrUserError
        def initialize(msg = nil)
            super real_msg: msg ? msg : "user denied access"
        end
    end

    class WrongOrMissingState < AuthReportableError
        def code
            WEBrick::HTTPStatus::RC_UNAUTHORIZED
        end
    end

    class MissingCodeError < AuthReportableError
        def initialize(msg = nil)
            super msg ? msg : "missing code"
        end

        def code
            WEBrick::HTTPStatus::RC_BAD_REQUEST
        end
    end

    class AuthCanceledError < OAuth2Error
    end

    class AuthManualCanceledError < AuthCanceledError
    end

    class AuthTimeoutedError < AuthCanceledError
    end
end

#TODO remove testing script

if caller.length == 0
    Spotify::Token.new_token { |error| puts error }

    loop { Spotify::Token.cancel_new_token if gets == "!\n" }
end
