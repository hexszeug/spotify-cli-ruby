# frozen_string_literal: true

module Main
  module DefCmd
    class Echo
      include Command

      def initialize(dispatcher)
        dispatcher.register(
          literal('echo').executes do
            UI.print_raw('')
          end.then(
            Arguments::GreedyString.new(:str).executes do |ctx|
              UI.print_raw(ctx[:str])
            end
          )
        )
      end
    end
  end
end
