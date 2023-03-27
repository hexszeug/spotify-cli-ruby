# frozen_string_literal: true

module Main
  module DefCmd
    module Utils
      # @todo delete and replace functionality
      def explain_error(error)
        <<~TEXT
          $rAn error occured: #{error.class}
          #{error.backtrace&.map { |s| "  #{s}" }&.join("\n")}
        TEXT
      end

      def explain_user(user)
        <<~TEXT
          $*#{user[:display_name]}$* $%(#{user[:uri]})$%
          $_#{user[:email]}$_ $Y#{user[:product]}$0c
          Followers: #{user[:followers][:total]}
        TEXT
      end
    end
  end
end
