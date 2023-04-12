# frozen_string_literal: true

module Spotify
  module API
    class Pagination
      DEFAULT_MAX_OFFSET = 1000

      attr_reader :limit, :offset

      def initialize(limit = Float::INFINITY, offset: 0)
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

        each_page_recursive(source, other) do |src, oth|
          src[:items] += oth[:items]
          src[:offset] = oth[:offset]
          src[:next] = oth[:next]
        end
      end

      def next?(pagy)
        nxt = false
        each_page_recursive(pagy) do |page|
          nxt = true unless page[:next].nil?
        end
        nxt
      end

      def each_page_recursive(*pagies, &)
        if page?(pagies.first)
          yield(*pagies)
          return
        end

        pagies.first.each_key do |key|
          pages = pagies.map { |pagy| pagy[key] }
          next if pages.any?(&:nil?)

          each_page_recursive(*pages, &)
        end
      end

      def page?(obj)
        obj[:items].is_a?(Array) &&
          %i[offset limit total].all? { |key| obj[key].is_a?(Integer) }
      end
    end
  end
end
