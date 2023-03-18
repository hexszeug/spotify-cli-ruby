# frozen_string_literal: true

module Main
  module DefCmd
    class Me
      include Command

      def initialize(dispatcher)
        dispatcher.register(
          literal('me').executes do
            Spotify::API.request('/me') do |user|
              UI.print(user.to_s)
            end.error do |e|
              UI.print(e.class.to_s)
            end
          end
        )
      end
    end
  end
end
