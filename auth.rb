require './spotify_api'
require 'launchy'
require 'uri'
require 'socket'
require 'base64'

module Auth
    ID = '4388096316894b88a147b53559d0c14a'
    SECRET = 'c769df8ae055480ea18b6405c0d60502'
    HUMAN_AUTH_PROMPT_URI = 'https://accounts.spotify.com/authorize/'
    CALLBACK_PORT = 80
    CALLBACK_URI = "http://localhost:#{CALLBACK_PORT}/callback/"
    CALLBACK_PARSE = /^GET \/callback\/\?([^ .]*) HTTP\/1\.1\r$/
    CALLBACK_SUCESS_URI = 'https://google.com'
    CALLBACK_SUCESS_RESPONSE = "HTTP/1.1 301 Moved Permanently\r\nlocation: #{CALLBACK_SUCESS_URI}\r\n"
    TOKEN_REQUEST_URI = 'https://accounts.spotify.com/api/token'
    BASIC_AUTH = Base64.strict_encode64("#{ID}:#{SECRET}")
    
    def Auth.new_user show_dialog=true
        # generate random state
        state = 'state' #TODO generate random state
        
        # open human auth prompt
        human_auth_prompt_query = {
            'client_id' => ID,
            'response_type' => 'code',
            'redirect_uri' => CALLBACK_URI,
            'state' => state,
            'scope' => '',
            'show_dialog' => show_dialog
        }
        Launchy.open "#{HUMAN_AUTH_PROMPT_URI}?#{URI.encode_www_form human_auth_prompt_query}"
        
        # receive code from callback
        code = nil
        TCPServer.open CALLBACK_PORT do |server|
            loop do #TODO more readable logic
                client = server.accept
                response = client.gets.match CALLBACK_PARSE #TODO better timeout handeling
                unless response
                    client.close
                    next
                end
                q = Hash[URI.decode_www_form response[1]]
                if !q['state'] || q['state'] != state
                    client.close
                    next
                end
                if q['error']
                    client.close
                    raise q['error'] #TODO better error handeling
                end
                code = q['code']
                client.puts CALLBACK_SUCESS_RESPONSE
                client.close
                break
            end
        end
        puts "code: #{code}" #TODO improve debug messages

        # request token
        lol = post TOKEN_REQUEST_URI, {}, {
            'authorization' => "Basic #{BASIC_AUTH}",
            'content-type' => 'application/x-www-form-urlencoded'
            }, {
                'grant_type' => 'authorization_code',
                'code' => code,
                'redirect_uri' => CALLBACK_URI
            }
        puts lol.body
    end
        
end

Auth.new_user