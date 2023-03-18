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
        #
        # @return [Hash] of [page] (of requested type)
        def search_for_item(
          q:, type:,
          include_external: nil,
          pagination: API::Pagination.new(20),
          &block
        )
          query = { q:, type: }
          query.update(include_external:) unless include_external.nil?
          pagination.with_limit(50, 1000, callback: block) do |page|
            API.request('/search', query: query.merge(page))
          end
        end
      end
    end
  end
end
