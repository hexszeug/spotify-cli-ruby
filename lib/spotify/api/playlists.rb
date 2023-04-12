# frozen_string_literal: true

module Spotify
  module API
    module Playlists
      class << self
        ##
        # Get a playlist owned by a Spotify user.
        #
        # @param playlist_id [playlist_id]
        # @param fields [API::Fields] *(optional)*
        # @param additional_types [Array] of [:track], [:episode] *(optional)*
        #
        # @return [playlist]
        def get_playlist(playlist_id:, fields: nil, additional_types: nil, &)
          query = {}
          query.update(additional_types:) unless additional_types.nil?
          query[:fields] = fields.to_s unless fields.nil?
          API.request("/playlists/#{playlist_id}", query:, &)
        end

        ##
        # Change a playlist's name and public/private state. (The user must, of
        # course, own the playlist.)
        #
        # @param playlits_id [playlist_id]
        # @param name [String] *(optional)*
        # @param public [Boolean] *(optional)*
        # @param collaborative [Boolean] *(optional)*
        # @param description [String] *(optional)*
        def change_playlist_details(
          playlist_id:,
          name: nil,
          public: nil,
          collaborative: nil,
          description: nil,
          &
        )
          query = {}
          query.update(name:) unless name.nil?
          query.update(public:) unless public.nil?
          query.update(collaborative:) unless collaborative.nil?
          query.update(description:) unless description.nil?
          API.request("/playlists/#{playlist_id}", :put, query:, &)
        end

        ##
        # Get full details of the items of a playlist owned by a Spotify user.
        #
        # @param playlits_id [playlist_id]
        # @param fields [API::Fields] *(optional)*
        # @param pagination [API::Pagination]
        # @param additional_types [Array] of [:track], [:episode] *(optional)*
        #
        # @return [page/playlist_item]
        def get_playlist_items(
          playlist_id:,
          fields: nil,
          pagination: Pagination.new(20),
          additional_types: nil,
          &block
        )
          query = {}
          unless fields.nil?
            query[:fields] =
              "#{fields}#{Fields.new({ offset: true, limit: true,
                                       total: true })}"
          end
          query.update(additional_types:) unless additional_types.nil?
          pagination.with_limit(50, callback: block) do |page|
            API.request(
              "/playlists/#{playlist_id}/tracks",
              query: query.merge(page)
            )
          end
        end

        ##
        # Either reorder or replace items in a playlist depending on the
        # request's parameters. To reorder items, include range_start,
        # insert_before, range_length and snapshot_id in the request's body.
        # To replace items, include uris as either a query parameter or in the
        # request's body. Replacing items in a playlist will overwrite its
        # existing items. This operation can be used for replacing or clearing
        # items in a playlist.
        #
        # ***Note**: Replace and reorder are mutually exclusive operations which
        # share the same endpoint, but have different parameters. These
        # operations can't be applied together in a single request.*
        #
        # @param uris [Array] of [track/uri] or [episode/uri]
        # @param range [Range]
        # @param insert_before [Integer]
        # @param snapshot_id [snapshot_id] *(optional)*
        #
        # @return [Hash] of [snapshot_id]
        def update_playlist_items(
          insert_before:,
          uris: nil,
          range: nil,
          snapshot_id: nil,
          &
        )
          range ||= 0..0
          body = { insert_before: }
          if uris.nil?
            body[:range_start] = range.begin
            body[:range_length] = range.size
          else
            body.update(uris:)
          end
          body.update(snapshot_id:) unless snapshot_id.nil?
          API.request("/playlists/#{playlist_id}/tracks", :put, body:, &)
        end

        ##
        # Add one or more items to a user's playlist.
        #
        # @param playlist_id [playlist_id]
        # @param position [Integer]
        # @param uris [Array] of [track/uri] or [episode/uri]
        #
        # @return [Hash] of [snapshot_id]
        def add_items_to_playlist(playlist_id:, position:, uris:, &)
          API.request(
            "/playlists/#{playlist_id}/tracks",
            :post,
            body: { position:, uris: },
            &
          )
        end

        ##
        # Remove one or more items from a user's playlist.
        #
        # @param playlist_id [playlist_id]
        # @param tracks [Array] of [track]
        # @param snapshot_id [snapshot_id] *(optional)*
        #
        # @return [Hash] of [snapshot_id]
        def remove_playlist_items(playlist_id:, tracks:, snapshot_id: nil, &)
          body = { tracks: }
          body.update(snapshot_id:) unless snapshot_id.nil?
          API.request("/playlists/#{playlist_id}/tracks", :delete, body:, &)
        end

        ##
        # Get a list of the playlists owned or followed by the current Spotify
        # user.
        #
        # @param pagination [API::Pagination]
        #
        # @return [page/playlist]
        def get_current_users_playlists(pagination: Pagination.new(20), &block)
          pagination.with_limit(50, callback: block) do |page|
            API.request('/me/playlists', query: page)
          end
        end

        ##
        # Get a list of the playlists owned or followed by a Spotify user.
        #
        # @param user_id [user_id]
        # @param pagination [API::Pagination]
        #
        # @return [page/playlist]
        def get_users_playlists(
          user_id:,
          pagination: Pagination.new(20),
          &block
        )
          pagination.with_limit(50, callback: block) do |page|
            API.request("/users/#{user_id}/playlists", query: page)
          end
        end

        ##
        # Create a playlist for a Spotify user. (The playlist will be empty
        # until you add tracks.)
        #
        # @param user_id [user_id]
        # @param name [String]
        # @param public [Boolean] *(optional)*
        # @param collaborative [Boolean] *(optional)*
        # @param description [String] *(optional)*
        def create_playlist(
          user_id:,
          name:,
          public: nil,
          collaborative: nil,

          description: nil,
          &
        )
          body = { name: }
          body.update(public:) unless public.nil?
          body.update(collaborative:) unless collaborative.nil?
          body.update(description:) unless description.nil?
          API.request("/users/#{user_id}/playlists", :post, body:)
        end

        ##
        # Get a list of Spotify featured playlists (shown, for example, on a
        # Spotify player's 'Browse' tab).
        #
        # @param country [ISO 3166-1 alpha-2 country code] *(optional)*
        # @param locale [lowercase ISO 639-1 language code `_` uppercase ISO
        #   3166-1 alpha-2 country code] *(optional)*
        # @param timestamp [ISO 8601 timestamp] *(optional)*
        # @param pagination [API::Pagination]
        #
        # @return [Hash] of [message] and [page/playlist]
        def get_featured_playlists(
          country: nil,
          locale: nil,
          timestamp: nil,
          pagination: Pagination.new(20),
          &block
        )
          query = {}
          query.update(country:) unless country.nil?
          query.update(locale:) unless locale.nil?
          query.update(timestamp:) unless timestamp.nil?
          # @todo pagination doesnt support response type yet
          pagination.with_limit(50, callback: block) do |page|
            API.request('/browse/featured-playlists', query: query.merge(page))
          end
        end

        ##
        # Get a list of Spotify playlists tagged with a particular category.
        #
        # @param category_id [category_id]
        # @param country [ISO 3166-1 alpha-2 country code] *(optional)*
        # @param pagination [API::Pagination]
        #
        # @return [Hash] of [message] and [page/playlist]
        def get_categorys_playlists(
          category_id:,
          country: nil,
          pagination: Pagination.new(20),
          &block
        )
          query = {}
          query.update(country:) unless country.nil?
          # @todo pagination doesnt support response type yet
          pagination.with_limit(50, callback: block) do |page|
            API.request(
              "/browse/categories/#{category_id}/playlists",
              query: query.merge(page)
            )
          end
        end

        ##
        # Get the current image associated with a specific playlist.
        #
        # @param playlist_id [playlist_id]
        #
        # @return [Array] of [image]
        def get_playlist_cover_image(playlist_id:, &)
          API.request("/playlists/#{playlist_id}/images", &)
        end

        ##
        # Replace the image used to represent a specific playlist.
        #
        # @param playlist_id [playlist_id]
        # @param image [base64 endcoded image]
        def add_custom_playlist_cover_image(playlist_id:, image:, &)
          API.request("/playlists/#{playlist_id}/images", :put, body: image, &)
        end
      end
    end
  end
end
