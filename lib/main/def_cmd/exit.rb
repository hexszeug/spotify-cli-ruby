module Main
  module DefCmd
    class Exit
      include Command

      def initialize(dispatcher)
        dispatcher.register(literal('exit').executes { UI.stop_loop })
      end
    end
  end
end
