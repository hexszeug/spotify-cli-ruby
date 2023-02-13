require 'launchy'
require 'uri'
require 'socket'

ID = '4388096316894b88a147b53559d0c14a'
SECRET = 'c769df8ae055480ea18b6405c0d60502'
REDIRECT = 'http://localhost:80/callback/'
AUTH_URL = 'https://accounts.spotify.com/authorize/'

def new_user
    state = 'state' #TODO
    show_dialog = true #TODO
    regexp = Regexp.new "^GET /callback/\\?code=(.*)&state=#{URI.encode_www_form_component state} HTTP/1\\.1\\r$"

    query = {
        'client_id' => ID,
        'response_type' => 'code',
        'redirect_uri' => REDIRECT,
        'state' => state,
        'scope' => '',
        'show_dialog' => show_dialog
    }
    
    Launchy.open "#{AUTH_URL}?#{URI.encode_www_form query}"

    server = TCPServer.new 80
    code = nil
    loop do
        client = server.accept
        response = client.gets.match regexp
        unless response
            client.close
            next
        end
        code = response[1]
        break
    end
    server.close
end

new_user