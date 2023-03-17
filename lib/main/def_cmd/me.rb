# frozen_string_literal: true

module Main
  module DefCmd
    class Me
      include Command

      def initialize(dispatcher)
        dispatcher.register(
          literal('me').executes do
            UI.print(Spotify::API.request('/me').to_s)
          end
        )
      end
    end
  end
end
