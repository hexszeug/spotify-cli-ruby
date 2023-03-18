# frozen_string_literal: true

module Spotify
  module API
    module Search
      class << self
        ##
        # Get Spotify catalog information about albums, artists, playlists,
        # tracks, shows, episodes or audiobooks that match a keyword string.
        # **Note: Audiobooks are only available for the US, UK, Ireland, New
        # Zealand and Australia markets.**
        #
        # @param q [String] the search query
        # @param type [Array] of [:album], [:artist], [:playlist], [:track],
        #   [:show], [:episode], [:audiobook]
        # @param include_external [:audio] *(optional)* if provided display
        #   externally hostet audio as playable
        def search_for_item(q:, type:, include_external: nil, &)
          # @todo pagination
          query = { q:, type: }
          query.update(include_external:) unless include_external.nil?
          API.request('/search', query:, &)
        end
      end
    end
  end
end
