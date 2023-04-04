# frozen_string_literal: true

module Spotify
  module API
    module Player
      class << self
        ##
        # Get information about the user’s current playback state, including
        # track or episode, progress, and active device.
        #
        # @param additional_types [Array] of [:track], [:episode] *(optional)*
        #
        # @return [playback_state]
        def get_playback_state(additional_types: nil, &)
          query = additional_types.nil? ? {} : { additional_types: }
          API.request('/me/player', query:, &)
        end

        ##
        # Transfer playback to a new device and determine if it should start
        # playing.
        #
        # @param device_id [device/id]
        # @param play [false] *(default)* leave it as it is
        # @param play [true] force start of playback
        def transfer_playback(device_id:, play: false, &)
          API.request('/me/player', :put, body: {
                        device_ids: [device_id],
                        play:
                      }, &)
        end

        ##
        # Get information about a user’s available devices.
        #
        # @return [Array] of [device]
        def get_available_devices(&)
          API.request('/me/player/devices', &)
        end

        ##
        # Get the object currently being played on the user's Spotify account.
        #
        # @param additional_types [Array] of [:track], [:episode] *(optional)*
        #
        # @return [playback_state]
        def get_currently_playing_track(additional_types: nil, &)
          query = additional_types.nil? ? {} : { additional_types: }
          API.request('/me/player/currently-playing', query:, &)
        end

        ##
        # Start a new context or resume current playback on the user's active
        # device.
        #
        # **Resumes playback if neither uris nor context_uri is provided.**
        #
        # @param uris [Array] of [track/uri] *(optional)*
        # @param context_uri [album/uri] *(optional)*
        # @param context_uri [artist/uri] *(optional)*
        # @param context_uri [playlist/uri] *(optional)*
        # @param offset [Integer] *(default=0)* offset in context
        #   (only if context uri provided)
        # @param device_id [device/id] *(optional)*
        def start_resume_playback(
          uris: nil,
          context_uri: nil,
          offset_position: nil,
          offset_uri: nil,
          device_id: nil,
          &
        )
          query = device_id.nil? ? {} : { device_id: }
          if context_uri.nil?
            body = { uris: }
          else
            body = { context_uri: }
            unless offset_position.nil?
              body[:offset] = { position: offset_position }
            end
            body[:offset] = { uri: offset_uri } unless offset_uri.nil?
          end
          API.request('/me/player/play', :put, query:, body:, &)
        end

        ##
        # Pause playback on the user's account.
        #
        # @param device_id [device/id] *(optional)*
        def pause_playback(device_id: nil, &)
          query = device_id.nil? ? {} : { device_id: }
          API.request('/me/player/pause', :put, query:, &)
        end

        ##
        # Skips to next track in the user’s queue.
        #
        # @param device_id [device/id] *(optional)*
        def skip_to_next(device_id: nil, &)
          query = device_id.nil? ? {} : { device_id: }
          API.request('/me/player/next', :post, query:, &)
        end

        ##
        # Skips to previous track in the user’s queue.
        #
        # @param device_id [device/id] *(optional)*
        def skip_to_previous(device_id: nil, &)
          query = device_id.nil? ? {} : { device_id: }
          API.request('/me/player/previous', :post, query:, &)
        end

        ##
        # Seeks to the given position in the user’s currently playing track.
        #
        # @param position_ms [Integer]
        # @param device_id [device/id] *(optional)*
        def seek_to_postiton(position_ms:, device_id: nil, &)
          query = { position_ms: }
          query.update({ device_id: }) unless device_id.nil?
          API.request('/me/player/seek', :put, query:, &)
        end

        ##
        # Set the repeat mode for the user's playback. Options are repeat-track,
        # repeat-context, and off.
        #
        # @param state [:track]
        # @param state [:context]
        # @param state [:off]
        # @param device_id [device/id] *(optional)*
        def set_repeat_mode(state:, device_id: nil, &)
          query = { state: }
          query.update({ device_id: }) unless device_id.nil?
          API.request('/me/player/repeat', :put, query:, &)
        end

        ##
        # Set the volume for the user’s current playback device.
        #
        # @param volume_percent [Integer]
        # @param device_id [device/id] *(optional)*
        def set_playback_volume(volume_percent:, device_id: nil, &)
          query = { volume_percent: }
          query.update({ device_id: }) unless device_id.nil?
          API.request('/me/player/volume', :put, query:, &)
        end

        ##
        # Toggle shuffle on or off for user’s playback.
        #
        # @param state [Boolean]
        # @param device_id [device/id] *(optional)*
        def toggle_playback_shuffle(state:, device_id: nil, &)
          query = { state: }
          query.update({ device_id: }) unless device_id.nil?
          API.request('/me/player/shuffle', :put, query:, &)
        end

        ##
        # Get tracks from the current user's recently played tracks. ***Note:***
        # *Currently doesn't support podcast episodes.*
        #
        # **It's possible to provide only one of after and before. If neither are
        # provided before defaults to the present.**
        #
        # @param after [Integer] timestamp in milliseconds
        # @param before [Integer] timestamp in milliseconds
        # @param limit [Integer] *(default=20)*
        #
        # @return [page/recently_played_track]
        def get_recently_played_tracks(after: nil, before: nil, limit: 20, &)
          limit = limit.clamp(1, 50)
          before = (Time.now.to_f * 1000).to_i if after.nil? && before.nil?
          query = { limit: }
          query.update(after:) unless after.nil?
          query.update(before:) unless before.nil?
          API.request('/me/player/recently-played', query:, &)
        end

        ##
        # Get the list of objects that make up the user's queue.
        #
        # @return [playback_queue]
        def get_the_users_queue(&)
          API.request('/me/player/queue', &)
        end

        ##
        # Add an item to the end of the user's current playback queue.
        #
        # @param uri [track/uri]
        # @param uri [episode/uri]
        # @param device_id [device/id] *(optional)*
        def add_item_to_playback_queue(uri:, device_id: nil, &)
          query = { uri: }
          query.update({ device_id: }) unless device_id.nil?
          API.request('/me/player/queue', :post, query:, &)
        end
      end
    end
  end
end
