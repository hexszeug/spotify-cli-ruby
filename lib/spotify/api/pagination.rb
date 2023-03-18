# frozen_string_literal: true

module Spotify
  module API
    class Pagination
      DEFAULT_MAX_OFFSET = 1000

      attr_reader :limit, :offset

      def initialize(limit: Float::INFINITY, offset: 0)
        @limit = limit if limit.is_a?(Integer) && limit.positive?
        @limit ||= Float::INFINITY
        @offset = offset.is_a?(Integer) && offset >= 0 ? offset : 0
      end

      ##
      # yields a query which can passed to a pagination endpoint
      #
      # @param page_limit [Integer] the limit per page
      # @param max_offset [Integer] the maximum offset
      # @param callback [Proc] *(optional)* runs async if provided
      # @param & a block with a syncronous api call returning a page
      #
      # @return [Spotify::Promise] *(when called with callback)*
      # @return [page]
      def with_limit(
        page_limit, max_offset = DEFAULT_MAX_OFFSET, callback: nil, &
      )
        if callback
          promise = Spotify::Promise.new(&callback)
          thread = Thread.new do
            promise.resolve(with_limit(page_limit, max_offset, &))
          rescue SpotifyError => e
            promise.fail(e)
          end
          return promise.on_cancel { thread.kill }
        end

        offset = @offset
        page = {}
        while offset < [@offset + @limit, max_offset].min
          limit = [page_limit, @limit - offset].min
          next_page = yield({ offset:, limit: })
          merge_pages(page, next_page)
          break unless next?(page)

          offset += page_limit
        end
        page
      end

      private

      def merge_pages(source, other)
        if source.empty?
          source.update(other)
          return
        end

        # @todo recursive search for pages
        source[:items] += other[:items]
        source[:offset] = other[:offset]
        source[:next] = other[:next]
      end

      def next?(page)
        # @todo recursive search for pages
        page[:total] > page[:items].length
      end
    end
  end
end
