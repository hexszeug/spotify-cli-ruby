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
        #
        # @return [page/artists]
        # @return [page/tracks]
        def get_users_top_items(type:, time_range: :medium_term, &)
          # @todo pagination
          API.request("/me/top/#{type}", query: { time_range: }, &)
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
      end
    end
  end
end
