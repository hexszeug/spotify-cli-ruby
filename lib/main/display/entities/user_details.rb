# frozen_string_literal: true

module Main
  module Display
    module Entities
      class UserDetails
        def initialize(screen_message)
          @screen_message = screen_message
          Context.register([screen_message.content[:uri]])
        end

        def context_updated
          @screen_message.touch
        end

        def delete
          Context.unhook(self)
        end

        def generate(_max_width)
          # @todo adjust display text for strange users
          user = @screen_message.content
          <<~TEXT
            $*#{user[:display_name]}$* $%(#{Context.hook(user[:uri], self)})$%
            $_#{user[:email]}$_ $Y#{user[:product]}$0c
            Followers: #{user[:followers][:total]}
          TEXT
        end
      end
    end
  end
end
