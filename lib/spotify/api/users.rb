# frozen_string_literal: true

module Spotify
  module API
    module Users
      class << self
        ##
        # Get detailed profile information about the current user (including the
        # current user's username).
        #
        # @return [user]
        def get_current_users_profile(&)
          API.request('/me', &)
        end

        ##
        # Get the current user's top artists or tracks based on calculated
        # affinity.
        #
        # @param type [:artists]
        # @param type [:tracks]
        # @param time_range [:long_term] several years
        # @param time_range [:medium_term] *(default)* 6 months
        # @param time_range [:short_term] 4 weeks
        # @param pagination [API::Pagination]
        #
        # @return [page/artists]
        # @return [page/tracks]
        def get_users_top_items(
          type:,
          time_range: :medium_term,
          pagination: API::Pagination.new(20),
          &block
        )
          query = { time_range: }
          pagination.with_limit(50, 50, callback: block) do |page|
            API.request("/me/top/#{type}", query: query.merge(page))
          end
        end

        ##
        # Get public profile information about a Spotify user.
        #
        # @param user_id [user_id]
        #
        # @return [user]
        def get_users_profile(user_id:, &)
          API.request("/users/#{user_id}", &)
        end

        ##
        # Add the current user as a follower of a playlist.
        #
        # @param playlist_id [playlist_id]
        # @param public [Boolean]
        def follow_playlist(playlist_id:, public: true, &)
          API.request(
            "/playlists/#{playlist_id}/followers",
            :put,
            body: { public: },
            &
          )
        end

        ##
        # Remove the current user as a follower of a playlist.
        #
        # @param playlist_id [playlist_id]
        def unfollow_playlist(playlist_id:, &)
          API.request("/playlists/#{playlist_id}/followers", :delete, &)
        end

        ##
        # Get the current user's followed artists.
        #
        # @param type [:artist] *(default)*
        # @param after [artist_id]
        # @param limit [Integer]
        #
        # @return [page/artist]
        def get_followed_artists(type: :artist, after: nil, limit: 20, &)
          # @todo make pagination support other cursor types than offset
          query = { type:, limit: }
          query.update(after:) unless after.nil?
          API.request('/me/following', query:, &)
        end

        ##
        # Add the current user as a follower of one or more artists or other
        # Spotify users.
        #
        # @param type [:artist]
        # @param type [:user]
        # @param ids [Array/artist_id]
        # @param ids [Array/user_id]
        def follow_artists_or_users(type:, ids:, &)
          API.request('/me/following', :put, query: { type:, ids: }, &)
        end

        ##
        # Remove the current user as a follower of one or more artists or other
        # Spotify users.
        #
        # @param type [:artist]
        # @param type [:user]
        # @param ids [Array/artist_id]
        # @param ids [Array/user_id]
        def unfollow_artists_or_users(type:, ids:, &)
          API.request('/me/following', :delete, query: { type:, ids: }, &)
        end

        ##
        # Check to see if the current user is following one or more artists or
        # other Spotify users.
        #
        # @param type [:artist]
        # @param type [:user]
        # @param ids [Array/artist_id]
        # @param ids [Array/user_id]
        #
        # @return [Array/Boolean]
        def check_if_user_follows_artists_or_users(type:, ids:, &)
          API.request('/me/following/contains', query: { type:, ids: }, &)
        end

        ##
        # Check to see if one or more Spotify users are following a specified
        # playlist.
        #
        # @param playlist_id [playlist_id]
        # @param ids [Array/user_id] *(max. 5)*
        #
        # @return [Array/Booleans]
        def check_if_users_follow_playlist(playlist_id:, ids:, &)
          API.request(
            "/playlists/#{playlist_id}/followers/contains",
            query: { playlist_id:, ids: },
            &
          )
        end
      end
    end
  end
end
