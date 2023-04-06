# frozen_string_literal: true

module Main
  module Context
    class URIArgument < Command::Node
      TYPES = %i[
        track
        artist
        album
        playlist
        show
        episode
        audiobook
        user
      ].freeze
      LITERAL_REGEXP =
        %r{^(?:(?<context>.*)/)?(?<uri>(?:\w+:)*(?<type>\w+):\w+)$}
      REFERENCE_REGEXP =
        %r{^(?:(?<type>\w+)[/:])?(?:(?<id>\d+)|(?<from>\d+)-(?<to>\d+))$}

      attr_reader :allow_types,
                  :allow_multiple,
                  :allow_mixed_types,
                  :with_context

      def initialize(
        name,
        default_type: :track,
        allow_types: TYPES,
        allow_multiple: true,
        allow_mixed_types: true,
        with_context: false
      )
        super(:argument, name)
        @default_type = default_type.to_s
        @allow_types = allow_types.map(&:to_s)
        @allow_multiple = allow_multiple
        @allow_mixed_types = allow_mixed_types
        @with_context = with_context
      end

      def <=>(other)
        return super(other) unless other.instance_of?(URIArgument)

        return if @allow_types.intersection(other.allow_types).empty?

        if @allow_multiple != other.allow_multiple
          @allow_multiple ? 1 : -1
        elsif @allow_mixed_types != other.allow_mixed_types
          @allow_mixed_types ? 1 : -1
        elsif @with_context != other.with_context
          @with_context ? -1 : 1
        else
          0
        end
      end

      def valid?(token)
        return false if !@allow_multiple && token.match?(/[,-]/)

        types = token.split(',').map do |str|
          uri_type_if_valid(str)
        end

        return false if !@allow_mixed_types && types.uniq.length > 1

        types.all? { |type| @allow_types.include?(type) }
      end

      def parse(token)
        uris = []
        token.split(',').each do |str|
          if (reference = str.match(REFERENCE_REGEXP))
            type = reference[:type] || @default_type
            if reference[:id].nil?
              reference[:from].to_i.upto(reference[:to].to_i) do |i|
                uris.push(parse_literal(Context.lookup(i, type)))
              end
            else
              id = reference[:id].to_i
              uris.push(parse_literal(Context.lookup(id, type)))
            end
          else
            uris.push(parse_literal(str))
          end
        end
        @allow_multiple ? uris : uris.first
      end

      private

      def uri_type_if_valid(str)
        if (literal = str.match(LITERAL_REGEXP))
          literal[:type] || @default_type
        elsif (reference = str.match(REFERENCE_REGEXP))
          return if reference[:from].to_i > reference[:to].to_i
          return if reference[:id].nil? && @single_uri_with_context

          index = (reference[:id] || reference[:to]).to_i
          type = reference[:type] || @default_type
          type unless Context.lookup(index, type).nil?
        end
      end

      def parse_literal(str)
        literal = str.match(LITERAL_REGEXP)
        uri = literal[:uri]
        if @with_context
          context = literal[:context]
          { uri:, context: }
        else
          uri
        end
      end
    end
  end
end
