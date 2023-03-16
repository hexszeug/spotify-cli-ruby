# frozen_string_literal: true

module Spotify
  class SpotifyError < StandardError
  end
end

require_relative 'spotify/auth'
require_relative 'spotify/request'
