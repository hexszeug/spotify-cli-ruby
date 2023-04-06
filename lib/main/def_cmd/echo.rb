# frozen_string_literal: true

module Main
  module DefCmd
    class Echo
      include Command
      include UI::PrintUtils

      def initialize(dispatcher)
        dispatcher.register(
          literal('echo').executes do
            print ''
          end.then(
            Arguments::GreedyString.new(:str).executes do |ctx|
              print ctx[:str]
            end
          )
        )
      end
    end
  end
end
