# frozen_string_literal: true

module Main
  module Display
    module Entities
      class UserDetails < UI::ScreenMessage
        private

        def update_content(user)
          # @todo adjust display text for strange users
          super(<<~TEXT)
            $*#{user[:display_name]}$* $%(#{user[:uri]})$%
            $_#{user[:email]}$_ $Y#{user[:product]}$0c
            Followers: #{user[:followers][:total]}
          TEXT
        end
      end
    end
  end
end
