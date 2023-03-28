# frozen_string_literal: true

module Main
  module Display
    module Entities
      class UserDetails < UI::ScreenMessage
        def initialize(user)
          Context.register([user[:uri]])
          super(user)
        end

        def context_updated
          @changed = true
        end

        private

        def update_content(user)
          # @todo adjust display text for strange users
          super(<<~TEXT)
            $*#{user[:display_name]}$* $%(#{Context.hook(user[:uri], self)})$%
            $_#{user[:email]}$_ $Y#{user[:product]}$0c
            Followers: #{user[:followers][:total]}
          TEXT
        end
      end
    end
  end
end
