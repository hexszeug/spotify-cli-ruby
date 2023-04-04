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
      ].freeze
      LITERAL_REGEXP =
        %r{^(?:(?<context>.*)/)?(?<uri>(?:\w+:)*(?<type>\w+):\w+)$}
      REFERENCE_REGEXP =
        %r{^(?:(?<type>\w+)[/:])?(?:(?<id>\d+)|(?<from>\d+)-(?<to>\d+))$}

      attr_reader :allow_types, :single_uri_with_context

      def initialize(
        name,
        default_type: :track,
        allow_types: TYPES,
        allow_mixed_types: false,
        single_uri_with_context: false
      )
        super(:argument, name)
        @default_type = default_type.to_s
        @allow_types = allow_types.map(&:to_s)
        @allow_mixed_types = allow_mixed_types
        @single_uri_with_context = single_uri_with_context
      end

      def <=>(other)
        return super(other) unless other.instance_of?(URIArgument)

        if @single_uri_with_context == other.single_uri_with_context
          0 unless @allow_types.instersection(other.allow_types).empty?
        else
          @single_uri_with_context ? -1 : 1
        end
      end

      def valid?(token)
        types = token.split(',').map do |str|
          uri_type_if_valid(str)
        end
        return false if types.length > 1 && @single_uri_with_context

        (@allow_mixed_types || types.uniq.length == 1) &&
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
        @single_uri_with_context ? uris.first : uris
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
        if @single_uri_with_context
          context = literal[:context]
          { uri:, context: }
        else
          uri
        end
      end
    end
  end
end
