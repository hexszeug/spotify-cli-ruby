require './spotify_api'
require 'launchy'
require 'uri'
require 'socket'
require 'base64'
require 'json'

module Auth
    ID = '4388096316894b88a147b53559d0c14a'
    SECRET = '77f2373853974699824602358ecdf9bd'
    SCOPE = ''
    HUMAN_AUTH_PROMPT_URI = 'https://accounts.spotify.com/authorize/'
    CALLBACK_PORT = 80
    CALLBACK_URI = "http://localhost:#{CALLBACK_PORT}/callback/"
    CALLBACK_PARSE = /^GET \/callback\/\?(?<query>[^ .]*) HTTP\/1\.1\r$/
    CALLBACK_SUCESS_URI = 'https://google.com'
    CALLBACK_SUCESS_RESPONSE = "HTTP/1.1 301 Moved Permanently\r\nlocation: #{CALLBACK_SUCESS_URI}\r\n"
    TOKEN_REQUEST_URI = 'https://accounts.spotify.com/api/token'
    
    def Auth.new_user show_dialog=true
        # generate random state
        state = 'state' #TODO generate random state
        
        # open human auth prompt
        query = {
            client_id: ID,
            response_type: 'code',
            redirect_uri: CALLBACK_URI,
            state: state,
            scope: SCOPE,
            show_dialog: show_dialog
        }
        Launchy.open "#{HUMAN_AUTH_PROMPT_URI}?#{URI.encode_www_form query}"
        
        # receive code from callback
        code = nil
        TCPServer.open CALLBACK_PORT do |server|
            loop do #TODO more readable logic
                client = server.accept
                res = client.gets.match CALLBACK_PARSE #TODO better timeout handeling
                unless res
                    client.close
                    next
                end
                res_query = Hash[URI.decode_www_form res[:query]].transform_keys &:to_sym
                if !res_query[:state] || res_query[:state] != state
                    client.close
                    next
                end
                if res_query[:error]
                    client.close
                    raise res_query[:error] #TODO better error handeling
                end
                code = res_query[:code]
                client.puts CALLBACK_SUCESS_RESPONSE
                client.close
                break
            end
        end
        puts "code: #{code}" #TODO improve debug messages

        # create user
        user = User.new code, redirect_uri: CALLBACK_URI
        user.refresh_token #TODO debug. please remove
    end
    
    class User
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
            res = Request.post TOKEN_REQUEST_URI, header: header, body: body #TODO error handling
            json = sym_keys JSON[res.body]
            puts json #TODO better debug messages
            @access_token = json[:access_token]
            @expires_in = json[:expires_in]
            @refresh_token = json[:refresh_token]

            #TODO setup expiration stuff and so on

            # request email

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
            res = Request.post TOKEN_REQUEST_URI, header: header, body: body #TODO better error handling
            res_json = sym_keys JSON[res.body]
            @access_token = res_json[:access_token]
            @expires_in = res_json[:expires_in] #TODO setup expiration stuff
            puts res_json #TODO better debug messages
        end
    end
end

def sym_keys hash
    return hash.transform_keys &:to_sym
end

Auth.new_user