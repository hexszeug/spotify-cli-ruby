require './spotify_api'
require 'launchy'
require 'uri'
require 'socket'
require 'base64'
require 'json'

module Auth
    ID = '4388096316894b88a147b53559d0c14a'
    SECRET = 'c769df8ae055480ea18b6405c0d60502'
    SCOPE = ''
    HUMAN_AUTH_PROMPT_URI = 'https://accounts.spotify.com/authorize/'
    CALLBACK_PORT = 80
    CALLBACK_URI = "http://localhost:#{CALLBACK_PORT}/callback/"
    CALLBACK_PARSE = /^GET \/callback\/\?(?<query>[^ .]*) HTTP\/1\.1\r$/
    CALLBACK_SUCESS_URI = 'https://google.com'
    CALLBACK_SUCESS_RESPONSE = "HTTP/1.1 301 Moved Permanently\r\nlocation: #{CALLBACK_SUCESS_URI}\r\n"
    TOKEN_REQUEST_URI = 'https://accounts.spotify.com/api/token'
    BASIC_AUTH = "Basic #{Base64.strict_encode64("#{ID}:#{SECRET}")}"
    
    def Auth.new_user show_dialog=true
        # generate random state
        state = 'state' #TODO generate random state
        
        # open human auth prompt
        human_auth_prompt_query = {
            client_id: ID,
            response_type: 'code',
            redirect_uri: CALLBACK_URI,
            state: state,
            scope: SCOPE,
            show_dialog: show_dialog
        }
        Launchy.open "#{HUMAN_AUTH_PROMPT_URI}?#{URI.encode_www_form human_auth_prompt_query}"
        
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

        # request token
        req_token_header = {
            authorization: BASIC_AUTH,
            'content-type': 'application/x-www-form-urlencoded'
        }
        req_token_body = {
            grant_type: 'authorization_code',
            code: code,
            redirect_uri: CALLBACK_URI
        }
        token_res = Request.post TOKEN_REQUEST_URI, {}, req_token_header, req_token_body
        puts token_res.body
    end
        
end

Auth.new_user