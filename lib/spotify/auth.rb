require_relative "spotify.rb"

require "uri"
require "securerandom"
require "base64"

require "launchy"
require "webrick"

#TODO replace "&callback" arguments with "yield", "block_given?" and "&proc" syntax

module Spotify
    module URLs
        AUTH_PROMPT = "https://accounts.spotify.com/authorize/"
        AUTH_REDIRECT = "http://localhost:8888/callback/"
        AUTH_TOKEN = "https://accounts.spotify.com/api/token/"
    end

    module Token
        include WEBrick

        PROMPT_TIMEOUT_SEC = 5 * 60

        TOKEN_DIR = Dir.home + "/.spotify-cli-ruby"
        TOKEN_PATH = TOKEN_DIR + "/token.json"

        SUCCESS_HTML_PATH = Dir.pwd + "/static/success.html"
        ERROR_HTML_PATH = Dir.pwd + "/static/error.html"

        HTTP_SERVER_CONFIG = Config::HTTP.update(Logger: BasicLog.new(nil, 0))

        APP_ID = "4388096316894b88a147b53559d0c14a"
        APP_SECRET = "77f2373853974699824602358ecdf9bd"

        def Token.access_token
            return @token ? @token[:access_token].dup : nil
        end

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
                set_token token_hash
            rescue JSON::JSONError, TokenParseError
                return false
            end
            return true
        end

        def Token.new_token(&callback)
            return false if @getting_token && Thread.current != @getting_token
            if callback
                @getting_token =
                    Thread.new callback do |callback|
                        begin
                            callback.call new_token
                        rescue OAuth2Error, TokenParseError => e
                            callback.call e
                        end
                    end
                @getting_token.name = "getting-token"
                return true
            end
            @getting_token = true unless @getting_token
            begin
                set_token request_token_by_code get_code
            ensure
                @getting_token = false
            end
            return true
        end

        def Token.cancel_new_token
            return false unless @getting_token.is_a?(Thread) && @getting_token.alive?
            @getting_token.raise AuthManualCanceledError.new
            return true
        end

        def Token.refresh_token(&callback)
            return false unless @token
            if callback
                return(
                    request_refresh_token(
                        @token[:refresh_token],
                        proc do |res|
                            if res.is_a? Exception
                                callback.call res
                            else
                                begin
                                    set_token res
                                rescue TokenParseError => e
                                    callback.call e
                                else
                                    callback.call true
                                end
                            end
                        end,
                    )
                )
            end

            return true
        end

        def self.set_token(token_hash)
            unless token_hash.is_a? Hash
                raise TokenParseError.new "token must be a hash"
            end
            token = token_hash.dup
            token.delete_if do |key|
                !%i[access_token refresh_token expires_in expires_at].include? key
            end
            unless token.key?(:access_token) && token[:access_token].is_a?(String)
                raise TokenParseError.new "missing access token"
            end
            if token.key?(:expires_in) && !token.key?(:expires_at) &&
                      token[:expires_in].is_a?(Integer)
                token[:expires_at] = Time.now.to_i + token[:expires_in]
            end
            token.delete :expires_in
            unless token.key?(:expires_at) && token[:expires_at].is_a?(Integer)
                raise TokenParseError.new "missing expiration infomation"
            end
            unless token.key?(:refresh_token) && token[:refresh_token].is_a?(String)
                raise TokenParseError.new "missing refresh token" unless @token
                @token.update token
            else
                @token = token
            end
            refresh_token {} if Time.now.to_i >= token[:expires_at]
            return true
        end

        def self.get_code
            state = SecureRandom.hex 16

            # open prompt
            uri = URI(Spotify::URLs::AUTH_PROMPT)
            query = {
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
            }
            uri.query = URI.encode_www_form(query)
            begin
                Launchy.open uri.to_s
            rescue Launchy::Error => e
                raise OpenUserPromptError.new e.message
            end

            # setup server variables
            redirect_uri = URI(Spotify::URLs::AUTH_REDIRECT)
            hostname, port = redirect_uri.hostname, redirect_uri.port
            threads = []
            sockets = []

            begin
                # start timeout thread
                timeout_thread =
                    Thread.new(Thread.current) do |thread|
                        sleep PROMPT_TIMEOUT_SEC
                        thread.raise AuthTimeoutedError.new
                    end
                timeout_thread.name = "getting token/code-server (timeout)"

                # server loop
                Socket.tcp_server_loop(hostname, port) do |socket|
                    sockets.push socket
                    thread =
                        Thread.new(Thread.current) do |server_thread|
                            begin
                                code = parse_code_server_request socket, state
                            rescue OAuth2Error => e
                                server_thread.raise e
                            end
                            server_thread.raise ReceivedCodeSignal.new code if code
                        end
                    threads.push thread
                    thread.name = "getting-token/code-server: client #{socket}"
                end
            rescue SystemCallError => e
                raise OpenCodeServerError.new e.message
            rescue ReceivedCodeSignal => code
                return code.to_s
            ensure
                timeout_thread.kill
                threads.each &:kill
                sockets.each &:close
            end
        end

        def self.parse_code_server_request(socket, state)
            begin
                req = HTTPRequest.new HTTP_SERVER_CONFIG
                res = HTTPResponse.new HTTP_SERVER_CONFIG
                req.parse socket
                if req.path != URI(Spotify::URLs::AUTH_REDIRECT).path
                    raise HTTPStatus::NoContent.new
                end
                query = req.query
                raise WrongOrMissingState.new "missing state" unless query.key?("state")
                unless query["state"] == state
                    raise WrongOrMissingState.new "wrong state `#{query["state"]}'"
                end
                if query.key?("error")
                    raise UserDeniedAccessError.new if query["error"] == "access_denied"
                    raise AuthCodeDenied.new query["error"]
                end
                raise MissingCodeError.new unless query.key?("code")
                # code received
                send_response res, socket
                return query["code"]
            rescue HTTPStatus::EOFError
            rescue AuthReportableError => e
                send_response res, socket, e
                raise e
            rescue HTTPStatus::Status => e
                send_response res, socket, e
            ensure
                socket.close
            end
            return nil
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
                "#{Spotify::MIME::HTML}; charset=#{res.body.encoding.name}" if res.body
            res.keep_alive = false
            res.setup_header
            res.header.delete "server" # is generated by setup_header
            begin
                res.send_header socket
                res.send_body socket
            rescue Exception
            end
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
            msg = error.message.sub("\n", "\\n")
            msg = "" if msg == error.class.name
            page.gsub! "$error_message", msg
            return page
        end

        def self.request_token_by_code(code)
            return(
                request_token_api(
                    {
                        grant_type: "authorization_code",
                        code: code,
                        redirect_uri: Spotify::URLs::AUTH_REDIRECT,
                    },
                )
            )
        end

        def self.request_refresh_token(refresh_token, callback = nil)
            return(
                request_token_api(
                    { grant_type: "refresh_token", refresh_token: refresh_token },
                    callback,
                )
            )
        end

        def self.request_token_api(body, callback = nil)
            uri = URI(Spotify::URLs::AUTH_TOKEN)
            header = {
                Authorization:
                    "Basic #{Base64.strict_encode64(APP_ID + ":" + APP_SECRET)}",
                "Content-Type": Spotify::MIME::POST_FORM,
            }
            req_body = URI.encode_www_form body
            if callback
                cancel =
                    Spotify::Request.http_request(uri, :post, header, req_body) do |res|
                        parse_token_response res
                    end
                return cancel
            end
            begin
                res = Spotify::Request.http_request uri, :post, header, req_body
            rescue RequestError => e
                res = e
            end
            return parse_token_response res
        end

        def self.parse_token_response(res)
            case res
            when CancelError
                raise AuthCanceledError.new res.message
            when TimeoutError
                raise AuthTimeoutedError.new res.message
            when RequestError
                raise AuthTokenRequestError.new res.message
            end
            begin
                body = JSON.parse res.body
            rescue JSON::JSONError
                raise AuthTokenRequestError.new "malformed response body"
            end
            raise AuthTokenDeniedError.new body[:error] unless res.code == "200"
            return body
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

    #TODO rename exception and implement custom behaviour (like only get message if custom provided)

    class TokenParseError < SpotifyError
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

    class AuthCodeDenied < AuthReportableError
        #TODO implement handling for codes mentioned in https://www.rfc-editor.org/rfc/rfc6749#section-4.1.2.1
        def initialize(msg = "", real_msg: nil)
            super real_msg ? real_msg : "Spotify\u24c7 error message: `#{msg}'"
        end

        def code
            WEBrick::HTTPStatus::RC_BAD_REQUEST
        end
    end

    class UserDeniedAccessError < AuthCodeDenied
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

    class AuthTokenRequestError < OAuth2Error
    end

    class AuthTokenDeniedError < OAuth2Error
        #TODO implement handling for code mentioned in https://www.rfc-editor.org/rfc/rfc6749#section-5.2
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
    Spotify::Token.new_token do |res|
        if res.is_a? Exception
            puts res
        elsif !res
            puts "failed to parse first token"
        else
            puts Spotify::Token.access_token
            Spotify::Token.refresh_token do |res|
                if res.is_a? Exception
                    puts res
                elsif !res
                    puts "failed to parse second token"
                else
                    puts Spotify::Token.access_token
                end
            end
        end
    end

    loop { Spotify::Token.cancel_new_token if gets == "!\n" }
end
