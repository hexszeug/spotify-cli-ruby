# frozen_string_literal: true

require 'uri'

module Spotify
  module API
    class << self
      BASE_URL = 'https://api.spotify.com/v1'

      def request(endpoint, method = :get, query: {}, body: nil)
        # @todo allow async call (with promise)
        uri = URI(BASE_URL + endpoint)
        uri.query = URI.encode_www_form(query)
        header = { authorization: "Bearer #{Auth::Token.access_token}" }
        body = JSON.generate(body) if body.is_a?(Hash)
        res = Request.http(uri, method, header, body)
        parse_response(res) if res.code[0] == '2'
        # @todo handle other response codes then success
      end

      private

      def parse_response(res)
        # @todo create spotify objects (user, album, song, playlist, etc.)
        # @todo parse non json / empty bodies (status codes 201-204)
        JSON.parse(res.body, symbolize_names: true)
      end
    end
  end
end
