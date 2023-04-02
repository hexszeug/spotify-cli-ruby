# frozen_string_literal: true

module Main
  module Context
    class URIArgument < Command::Node
      # @todo replace allow_mixed_contexts context_with_offset (or better name)
      # @todo return list of uris unless context_with_offset is set

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

      def initialize(
        name,
        default_type: :track,
        allow_types: TYPES,
        allow_mixed_types: false,
        allow_mixed_contexts: true
      )
        super(:argument, name)
        @default_type = default_type.to_s
        @allow_types = allow_types.map(&:to_s)
        @allow_mixed_types = allow_mixed_types
        @allow_mixed_contexts = allow_mixed_contexts
      end

      def valid?(token)
        types = []
        contexts = []
        token.split(',').all? do |str|
          if (reference = str.match(REFERENCE_REGEXP))
            type = reference[:type] || @default_type

            if reference[:id].nil?
              range = (reference[:from].to_i)..(reference[:to].to_i)

              range.size.positive? &&
                range.all? do |i|
                  valid_literal?(Context.lookup(i, type), types, contexts)
                end
            else
              id = reference[:id].to_i
              valid_literal?(Context.lookup(id, type), types, contexts)
            end
          else
            valid_literal?(str, types, contexts)
          end
        end
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
        uris
      end

      private

      def valid_literal?(str, types, contexts)
        return false if str.nil?
        return false unless (literal = str.match(LITERAL_REGEXP))

        type = literal[:type] || @default_type
        types.push(type)
        context = literal[:context]
        contexts.push(context)

        @allow_types.include?(type) &&
          (@allow_mixed_types || types.first == type) &&
          (@allow_mixed_contexts || contexts.first == context)
      end

      def parse_literal(str)
        literal = str.match(LITERAL_REGEXP)
        uri = literal[:uri]
        type = literal[:type]
        context = literal[:context]
        res = { uri:, type: }
        res.update(context:) unless context.nil?
        res
      end
    end
  end
end
