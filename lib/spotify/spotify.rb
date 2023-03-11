module Spotify
    class SpotifyError < StandardError
    end
end

require_relative "auth.rb"
require_relative "request.rb"
