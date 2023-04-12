# frozen_string_literal: true

module Spotify
  module API
    module Albums
      class << self
        ##
        # Get Spotify catalog information for a single album.
        #
        # @param id [album_id]
        #
        # @return [album]
        def get_album(id:, &)
          API.request("/albums/#{id}", &)
        end

        ##
        # Get Spotify catalog information for multiple albums identified by
        # their Spotify IDs.
        #
        # @param ids [Array/album_id]
        #
        # @return [Array/album]
        def get_several_albums(ids:, &)
          API.request('/albums', query: { ids: }, &)
        end

        ##
        # Get Spotify catalog information about an album’s tracks. Optional
        # parameters can be used to limit the number of tracks returned.
        #
        # @param id [album_id]
        # @param pagination [API::Pagination]
        #
        # @return [page/track]
        def get_album_tracks(album_id:, pagination: Pagination.new(20), &block)
          pagination.with_limit(50, callback: block) do |page|
            API.request("/albums/#{album_id}/tracks", query: page)
          end
        end

        ##
        # Get a list of the albums saved in the current Spotify user's 'Your
        # Music' library.
        #
        # @param pagination [API::Pagination]
        #
        # @return [page/saved_album]
        def get_users_saved_albums(pagination: Pagination.new(20), &block)
          pagination.with_limit(50, callback: block) do |page|
            API.request('/me/albums', query: page)
          end
        end

        ##
        # Save one or more albums to the current user's 'Your Music' library.
        #
        # @param ids [Array/album_id]
        def save_albums_for_current_user(ids:, &)
          API.request('/me/albums', :put, query: { ids: }, &)
        end

        ##
        # Remove one or more albums from the current user's 'Your Music'
        # library.
        #
        # @param ids [Array/album_id]
        def remove_users_saved_albums(ids:, &)
          API.request('/me/albums', :delete, query: { ids: }, &)
        end

        ##
        # Check if one or more albums is already saved in the current Spotify
        # user's 'Your Music' library.
        #
        # @param ids [Array/album_id]
        #
        # @return [Array/Boolean]
        def check_users_saved_albums(ids:, &)
          API.request('me/albums/contains', query: { ids: }, &)
        end

        ##
        # Get a list of new album releases featured in Spotify (shown, for
        # example, on a Spotify player’s “Browse” tab).
        #
        # @param country [ISO 3166-1 alpha-2 country code] *(optional)*
        # @param pagination [API::Pagination]
        #
        # @return [page/album]
        def get_new_releases(
          country: nil,
          pagination: Pagination.new(20),
          &block
        )
          pagination.with_limit(50, callback: block) do |page|
            page = page.merge(country:) unless country.nil?
            API.request('browse/new-releases', query: page)
          end
        end
      end
    end
  end
end
