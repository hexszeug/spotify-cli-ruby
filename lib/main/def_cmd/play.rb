# frozen_string_literal: true

module Main
  module DefCmd
    class Play
      include Command
      include UI::PrintUtils

      def initialize(dispatcher)
        dispatcher.register(
          literal('play').then(
            Context::URIArgument.new(
              :uris,
              allow_mixed_types: [:track],
              allow_mixed_contexts: false
            ).executes do |ctx|
              play(ctx[:uris])
            end
          )
        )
      end
    end

    private

    def play(uris)
      # @todo implement (and test uri_argument with it)
    end
  end
end
