# frozen_string_literal: true

module Spotify
  CONFIG_DIR = "#{Dir.home}/.spotify-cli-ruby".freeze

  class SpotifyError < StandardError
  end
end

require_relative 'spotify/auth'
require_relative 'spotify/request'
require_relative 'spotify/promise'
require_relative 'spotify/api'
