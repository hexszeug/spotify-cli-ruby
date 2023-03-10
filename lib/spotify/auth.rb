require_relative "spotify.rb"

require "uri"
require "securerandom"

require "launchy"
require "webrick"

module Spotify
    PROMPT_TIMEOUT_SEC = 5 * 60

    module URLs
        AUTH_PROPT = "https://accounts.spotify.com/authorize/"
        AUTH_REDIRECT = "http://localhost:8888/callback/"
    end

    module Token
        TOKEN_DIR = Dir.home + "/.spotify-cli-ruby"
        TOKEN_PATH = TOKEN_DIR + "/token.json"

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
                @getting_token.name = "getting token main"
                return true
            end
            @getting_token = true unless @getting_token
            begin
                set_token request_token get_code
            rescue OAuth2Error => e
                @getting_token = false
                raise e
            end
            @getting_token = false
            return @token[:access_token].dup
        end

        def Token.cancel_new_token
            return unless @getting_token.is_a? Thread && @getting_token.alive?
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
            begin
                redirect_uri = URI(Spotify::URLs::AUTH_REDIRECT)
                server_thread =
                    Thread.new(
                        redirect_uri.hostname,
                        redirect_uri.port,
                    ) do |hostname, port|
                        Timeout.timeout(PROMPT_TIMEOUT_SEC, AuthTimeoutedError) do
                            Socket.tcp_server_loop(hostname, port) do |socket|
                                begin
                                    #TODO parse code response
                                    socket.close
                                    break "testcode"
                                rescue AuthCanceledError => e
                                    socket.close
                                    raise e
                                ensure
                                    socket.close
                                end
                            end
                        end
                    end
                server_thread.name = "getting token receiving code server"
                server_thread.report_on_exception = false
                server_thread.join
            rescue SystemCallError => e
                # creation of tcp server failed (probably the port was blocked)
                # is passed to this thread through server_thread.join
                # (even when invoked before calling join)
                raise ReceiveCodeError.new e.message
            rescue AuthManualCanceledError => e
                # can be invoked on this thread ("getting token main") by any thread
                # pass exception to server_thread to close potential tcp connections
                # also kills server_thread and join passes exception back to this thread
                server_thread.raise e
                server_thread.join 1
                # manually kill server_thread if it failed to stop executing
                # also manually reraise the exception
                server_thread.kill
                raise e
            end

            # return code
            return server_thread.value
        end

        def self.request_token(code)
        end

        def self.refresh_token
        end
    end

    class OAuth2Error < SpotifyError
    end

    class OpenUserPromptError < OAuth2Error
    end

    class ReceiveCodeError < OAuth2Error
    end

    class UserDeniedAccessError < OAuth2Error
    end

    class AuthCanceledError < OAuth2Error
    end

    class AuthManualCanceledError < AuthCanceledError
    end

    class AuthTimeoutedError < AuthCanceledError
    end
end

Spotify::Token.new_token { |error| puts error }

loop { Spotify::Token.cancel_new_token if gets == "!" }
