require './spotify_api'
require 'launchy'
require 'uri'
require 'socket'
require 'base64'
require 'json'
require 'webrick'

module Auth
    ID = '4388096316894b88a147b53559d0c14a'
    SECRET = '77f2373853974699824602358ecdf9bd'
    private_constant :ID, :SECRET
    
    def Auth.new_account show_dialog: true
        # constants
        cSCOPE = 'ugc-image-upload user-read-playback-state user-modify-playback-state playlist-read-private user-follow-modify playlist-read-collaborative user-follow-read user-read-currently-playing user-read-playback-position user-library-modify playlist-modify-private playlist-modify-public user-read-email user-top-read user-read-recently-played user-read-private user-library-read'
        cPOPUP_URI = 'https://accounts.spotify.com/authorize/'
        cCALLBACK_HOSTNAME = 'localhost'
        cCALLBACK_PORT = 3000
        cCALLBACK_URI = "http://#{cCALLBACK_HOSTNAME}:#{cCALLBACK_PORT}/callback/"
        cCALLBACK_SUCCESS_URI = 'about:logo'

        # generate random state
        state = 'state' #TODO generate random state
        
        # open human auth prompt
        query = {
            client_id: ID,
            response_type: 'code',
            redirect_uri: cCALLBACK_URI,
            state: state,
            scope: cSCOPE,
            show_dialog: show_dialog
        }
        Launchy.open "#{cPOPUP_URI}?#{URI.encode_www_form query}"
        
        # receive code from callback
        server = TCPServer.new cCALLBACK_HOSTNAME, cCALLBACK_PORT
        code = nil
        until code
            client = server.accept
            req = WEBrick::HTTPRequest.new WEBrick::Config::HTTP
            res = WEBrick::HTTPResponse.new WEBrick::Config::HTTP
            #TODO better error responses
            begin
                req.parse client
            rescue WEBrick::HTTPStatus::Error => e
                res.set_error e
            end
            if req.query['state'] != state
                res.set_error WEBrick::HTTPStatus::BadRequest.new 'wrong or missing state'
            elsif req.query['error']
                res.set_error WEBrick::HTTPStatus::BadRequest.new 'user denied authorization'
                # raise req.query['error'] #TODO error handling: quit function
            elsif req.query['code']
                code = req.query['code']
                res.set_error WEBrick::HTTPStatus::MovedPermanently.new 'successfully authorized'
                res['location'] = cCALLBACK_SUCCESS_URI
            else
                res.set_error WEBrick::HTTPStatus::BadRequest.new 'missing code'
                raise 'response missing code' #TODO error handling: quit function
            end
            res.send_response client
            client.close
        end
        server.close
        puts "code: #{code}" #TODO improve debug messages

        # create account
        Account.new code, redirect_uri: cCALLBACK_URI
    end
    
    class Account
        @@TOKEN_REQUEST_URI = 'https://accounts.spotify.com/api/token'
        @@BASIC_AUTH = "Basic #{Base64.strict_encode64("#{ID}:#{SECRET}")}"

        def initialize code, redirect_uri:
            # request token
            header = {
                authorization: @@BASIC_AUTH,
                'content-type': 'application/x-www-form-urlencoded'
            }
            body = {
                grant_type: 'authorization_code',
                code: code,
                redirect_uri: redirect_uri
            }
            res = Request.post @@TOKEN_REQUEST_URI, header: header, body: body #TODO error handling
            json = JSON[res.body]
            @access_token = json['access_token']
            @expiration_timestamp = Time.now + json['expires_in']
            @refresh_token = json['refresh_token']
            puts json #TODO better debug messages

            @login_timestamp = Time.now

            # user profile
            @user = Spotify.get_current_users_profile account: self
        end

        def login_timestamp
            @login_timestamp
        end

        def user
            @user
        end

        def <=> other
            @login_timestamp <=> other.login_timestamp
        end

        def == other
            @user[:id] == other.user[:id]
        end

        def authorize header={}
            refresh_token if Time.now > @expiration_timestamp
            header.merge({authorization: "Bearer #{@access_token}"})
        end

        def authorize! header
            header.merge! authorize
        end

        def refresh_token
            header = {
                authorization: @@BASIC_AUTH,
                'content-type': 'application/x-www-form-urlencoded'
            }
            body = {
                grant_type: 'refresh_token',
                refresh_token: @refresh_token
            }
            res = Request.post @@TOKEN_REQUEST_URI, header: header, body: body #TODO better error handling
            json = JSON[res.body]
            @access_token = json['access_token']
            @expiration_timestamp = Time.now + json['expires_in']
            puts json #TODO better debug messages
        end
    end
end

account = Auth.new_account

loop do
    case gets.chomp
    when ''
        Spotify.skip_to_next account: account
    when '!'
        Spotify.skip_to_previous account: account
    end
end