# frozen_string_literal: true

module Spotify
  module API
    class Fields
      def initialize(fields)
        @fields = fields
      end

      def to_s
        stringify(@fields)
      end

      private

      def stringify(hash)
        hash.map do |key, value|
          case value
          when Hash
            if value.size == 1
              "#{key}.#{stringify(value)}"
            elsif value.size > 1
              "#{key}(#{stringify(value)})"
            end
          when false then "!#{key}"
          when true then key.to_s
          end
        end.compact.join(',')
      end
    end
  end
end
