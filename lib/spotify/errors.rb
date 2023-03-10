module Spotify
    class SpotifyError < StandardError
    end

    class TimeoutError < SpotifyError
    end
end
