# require_relative "../spotify"

require 'uri'
require 'securerandom'
require 'base64'

require 'launchy'
require 'webrick'

module Spotify
  module URLs
    AUTH_PROMPT = 'https://accounts.spotify.com/authorize/'
    AUTH_REDIRECT = 'http://localhost:8888/callback/'
    AUTH_TOKEN = 'https://accounts.spotify.com/api/token/'
  end

  module Auth
    module Login
      PROMPT_TIMEOUT_SEC = 5 * 60

      SUCCESS_HTML_PATH = Dir.pwd + '/static/success.html'
      ERROR_HTML_PATH = Dir.pwd + '/static/error.html'

      APP_ID = '4388096316894b88a147b53559d0c14a'
      APP_SECRET = '77f2373853974699824602358ecdf9bd'

      def self.new_token!
        return false if @getting_token && Thread.current != @getting_token

        if block_given?
          @getting_token =
            Thread.new do
              yield new_token!
            rescue OAuth2Error, TokenError => e
              yield e
            end
          @getting_token.name = 'getting-token'
          return(
              proc do
                unless @getting_token.is_a?(Thread) && @getting_token.alive?
                  return false
                end

                @getting_token.raise AuthManualCanceledError.new
                return true
              end
            )
        end

        @getting_token ||= true
        begin
          set_token request_token_by_code get_code
        ensure
          @getting_token = false
        end
        true
      end

      def self.refresh_token!
        return false unless Token.token?

        if block_given?
          cancel =
            request_token_api(
              {
                grant_type: 'refresh_token',
                refresh_token: Token.refresh_token
              }
            ) do |res|
              if res.is_a? Exception
                yield res
              else
                begin
                  Token.token = res
                rescue TokenError => e
                  yield e
                else
                  yield true
                end
              end
            end
          return cancel
        end
        true
      end

      def self.get_code
        state = SecureRandom.hex 16

        # open prompt
        uri = URI(Spotify::URLs::AUTH_PROMPT)
        query = {
          client_id: APP_ID,
          response_type: 'code',
          redirect_uri: Spotify::URLs::AUTH_REDIRECT,
          state:,
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
                ].join(' '),
          show_dialog: true
        }
        uri.query = URI.encode_www_form(query)
        begin
          Launchy.open uri.to_s
        rescue Launchy::Error => e
          raise OpenUserPromptError, e.message
        end

        @code = nil

        CodeServer.start(state) { |arg| @code = arg }

        until @code
        end
        @code
      end

      module CodeServer
        include WEBrick

        HTTP_SERVER_CONFIG = Config::HTTP.update(Logger: BasicLog.new(nil, 0))

        def self.start(state, &callback)
          return unless block_given?

          @state = state
          @callback = callback
          return if @server

          uri = URI(Spotify::URLs::AUTH_REDIRECT)
          begin
            @server = TCPServer.new uri.hostname, uri.port
          rescue SystemCallError => e
            raise OpenCodeServerError, e
          end
          Thread.new { server_loop }
        end

        def self.stop
          return unless @server

          @server.close
          @state = nil
          @callback = nil
        end

        def self.server_loop
          Thread.current.name = 'code-server/loop'
          begin
            while @server && !@server.closed?
              Thread.new(@server.accept) do |socket|
                res = handle_connection socket
                socket.close
              end
            end
          rescue IOError
          ensure
            @server.close if @server && !@server.closed?
            @server = nil
          end
        end

        def self.handle_connection(socket)
          Thread.current.name =
            "code-server/client(#{socket.peeraddr[2]}:#{socket.peeraddr[1]})"
          req = HTTPRequest.new HTTP_SERVER_CONFIG
          res = HTTPResponse.new HTTP_SERVER_CONFIG
          begin
            req.parse socket
          rescue HTTPStatus::BadRequest
            generate_response res, MalformedRequest.new
          rescue HTTPStatus::EOFError
            return # socket was probably closed thus not responding
          else
            handle_request req, res
          end

          res.keep_alive = false
          res.setup_header
          res.header.delete 'server' # is generated by HTTPResponse#setup_header
          begin
            res.send_header socket
            res.send_body socket
          rescue Exception # execution is not critical thus ignoring errors
          end
        end

        def self.handle_request(req, res)
          unless @state && req.path == URI(Spotify::URLs::AUTH_REDIRECT).path
            generate_response(res, NoContent.new)
            return
          end
          if req.query['state'] != @state
            generate_response(res, BadState.new(req.query['state']))
            return
          end
          unless req.query.key?('code')
            on_code_denied res, req['error']
            return
          end
          on_code_received(res, req.query['code'])
        end

        def self.on_code_denied(res, error_str)
          callback = @callback
          CodeServer.stop
          e = CodeDeniedError.new error_str
          Thread.new do
            Thread.current.name = 'code-server/return'
            callback.call e
          end
          generate_response res, e
        end

        def self.on_code_received(res, code)
          callback = @callback
          CodeServer.stop
          thread =
            Thread.new do
              Thread.current.name = 'code-server/return'
              Thread.report_on_exception = false
              callback.call code
            end
          begin
            thread.join
          rescue Exception => e
            generate_response res, e
          else
            generate_response res
          end
        end

        def self.generate_response(res, error = nil)
          # TODO: generate prettier response pages
          res.status = HTTPStatus::RC_BAD_REQUEST # default
          case error
          when nil
            res.status = HTTPStatus::RC_OK
            res.body = 'success'
          when MalformedRequest
            res.body = 'malformed request'
          when NoContent
            res.status = HTTPStatus::RC_NO_CONTENT
          when BadState
            res.body =
              error.state? ? "wrong state '#{error.state}'" : 'missing state'
          when CodeDeniedError
            # TODO: prettier response: parse error codes from https://www.rfc-editor.org/rfc/rfc6749#section-4.1.2.1
            res.body = "access denied. #{error.error_str}"
          else
            res.status = HTTPStatus::RC_INTERNAL_SERVER_ERROR
            res.body = 'internal error. see the cli for more information'
          end
        end
      end

      def self.parse_code_server_request(socket, state)
        begin
          req = HTTPRequest.new HTTP_SERVER_CONFIG
          res = HTTPResponse.new HTTP_SERVER_CONFIG
          req.parse socket
          if req.path != URI(Spotify::URLs::AUTH_REDIRECT).path
            raise HTTPStatus::NoContent
          end

          query = req.query
          raise WrongOrMissingState, 'missing state' unless query.key?('state')

          unless query['state'] == state
            raise WrongOrMissingState,
                  "wrong state `#{query['state']}'"
          end

          if query.key?('error')
            raise UserDeniedAccessError if query['error'] == 'access_denied'

            raise AuthCodeDenied, query['error']
          end
          raise MissingCodeError unless query.key?('code')

          # code received
          send_response res, socket
          return query['code']
        rescue HTTPStatus::EOFError
        rescue AuthReportableError => e
          send_response res, socket, e
          raise e
        rescue HTTPStatus::Status => e
          send_response res, socket, e
        ensure
          socket.close
        end
        nil
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
        if res.body
          res.content_type =
            "#{Spotify::MIME::HTML}; charset=#{res.body.encoding.name}"
        end
        res.keep_alive = false
        res.setup_header
        res.header.delete 'server' # is generated by setup_header
        begin
          res.send_header socket
          res.send_body socket
        rescue Exception
        end
      end

      def self.generate_success_page
        unless File.exist? SUCCESS_HTML_PATH
          return 'Done! You may close this tab now.'
        end

        File.read SUCCESS_HTML_PATH
      end

      def self.generate_error_page(error)
        unless File.exist? ERROR_HTML_PATH
          return "#{error.status} #{error.reason_phrase}"
        end

        page = File.read ERROR_HTML_PATH
        page.gsub! '$error_code', error.code.to_s
        page.gsub! '$error_name', error.reason_phrase
        msg = error.message.sub("\n", '\\n')
        msg = '' if msg == error.class.name
        page.gsub! '$error_message', msg
        page
      end

      def self.request_token_by_code(code)
        request_token_api(
          {
            grant_type: 'authorization_code',
            code:,
            redirect_uri: Spotify::URLs::AUTH_REDIRECT
          }
        )
      end

      def self.request_token_api(body)
        uri = URI(Spotify::URLs::AUTH_TOKEN)
        header = {
          Authorization:
                "Basic #{Base64.strict_encode64(APP_ID + ':' + APP_SECRET)}",
          'Content-Type': Spotify::MIME::POST_FORM
        }
        req_body = URI.encode_www_form body
        if block_given?
          cancel =
            Spotify::Request.http(uri, :post, header, req_body) do |res|
              yield parse_token_response res
            rescue OAuth2Error => e
              yield e
            end
          return cancel
        end
        begin
          res = Spotify::Request.http uri, :post, header, req_body
        rescue RequestError => e
          res = e
        end
        parse_token_response res
      end

      def self.parse_token_response(res)
        case res
        when CancelError
          raise AuthCanceledError, res.message
        when TimeoutError
          raise AuthTimeoutedError, res.message
        when RequestError
          raise AuthTokenRequestError, res.message
        end
        begin
          body = JSON.parse res.body, symbolize_names: true
        rescue JSON::JSONError
          raise AuthTokenRequestError, 'malformed response body'
        end
        raise AuthTokenDeniedError, body[:error] unless res.code == '200'

        body
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
  end

  # TODO: rename exception and implement custom behaviour ("message" only return message if custom provided in initialization of the error)

  # class OAuth2Error < SpotifyError
  # end

  # class OpenUserPromptError < OAuth2Error
  # end

  # class OpenCodeServerError < OAuth2Error
  # end

  # class AuthReportableError < OAuth2Error
  #     def code
  #         WEBrick::HTTPStatus::RC_INTERNAL_SERVER_ERROR
  #     end

  #     def reason_phrase
  #         WEBrick::HTTPStatus.reason_phrase code
  #     end
  # end

  # class AuthCodeDenied < AuthReportableError
  #     #TODO implement handling for codes mentioned in https://www.rfc-editor.org/rfc/rfc6749#section-4.1.2.1
  #     def initialize(msg = "", real_msg: nil)
  #         super real_msg ? real_msg : "Spotify\u24c7 error message: `#{msg}'"
  #     end

  #     def code
  #         WEBrick::HTTPStatus::RC_BAD_REQUEST
  #     end
  # end

  # class UserDeniedAccessError < AuthCodeDenied
  #     def initialize(msg = nil)
  #         super real_msg: msg ? msg : "user denied access"
  #     end
  # end

  # class WrongOrMissingState < AuthReportableError
  #     def code
  #         WEBrick::HTTPStatus::RC_UNAUTHORIZED
  #     end
  # end

  # class MissingCodeError < AuthReportableError
  #     def initialize(msg = nil)
  #         super msg ? msg : "missing code"
  #     end

  #     def code
  #         WEBrick::HTTPStatus::RC_BAD_REQUEST
  #     end
  # end

  # class AuthTokenRequestError < OAuth2Error
  # end

  # class AuthTokenDeniedError < OAuth2Error
  #     #TODO implement handling for code mentioned in https://www.rfc-editor.org/rfc/rfc6749#section-5.2
  # end

  # class AuthCanceledError < OAuth2Error
  # end

  # class AuthManualCanceledError < AuthCanceledError
  # end

  # class AuthTimeoutedError < AuthCanceledError
  # end
end

# TODO: remove testing script

if caller.length == 0
  Spotify::Auth::Login.new_token! do |res|
    if res.is_a? Exception
      puts "#{res.class}: #{res.message}"
    elsif !res
      puts 'failed to parse first token'
    else
      puts Spotify::Auth::Token.access_token
      Spotify::Auth::Login.refresh_token! do |res|
        if res.is_a? Exception
          puts res
        elsif !res
          puts 'failed to parse second token'
        else
          puts Spotify::Auth::Token.access_token
        end
      end
    end
  end

  loop { Spotify::Auth::Login.cancel_new_token if gets == "!\n" }
end
