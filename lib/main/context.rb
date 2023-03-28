# frozen_string_literal: true

module Main
  module Context
    @pools = Hash.new do |hash, key|
      hash[key] = []
    end
    @indices = {}
    @hooks = {}
    class << self
      def lookup(id, pool_id = :track)
        return nil unless id.positive?

        @pools[pool_id][id - 1]
      end

      def register(uris)
        changes = Set.new
        uris.reverse_each do |uri|
          pool = @pools[uri.split(':')[-2]]
          if (i = @indices[uri])
            pool.delete_at(i)
          end
          pool.insert(0, uri)
          changes += flush(pool)
        end
        publish(changes)
      end

      def hook(uri, hook)
        return unless hook.respond_to?(:context_updated)

        @hooks[hook] = uri
        @indices[uri] + 1
      end

      def unhook(hook)
        @hooks.delete(hook)
      end

      private

      def flush(pool)
        changes = Set.new
        pool.each_with_index do |uri, i|
          next if @indices[uri] == i

          @indices[uri] = i
          changes.add(uri)
        end
        changes
      end

      def publish(changes)
        @hooks.each do |hook, uri|
          hook.context_updated if changes.include?(uri)
        end
      end
    end
  end
end
