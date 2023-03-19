# frozen_string_literal: true

module Main
  module DefCmd
    module Utils
      def explain_error(error)
        <<~TEXT
          An error occured: #{error.class}
          #{error.backtrace&.map { |s| "  #{s}" }&.join("\n")}
        TEXT
      end

      def explain_user(user)
        <<~TEXT
          #{user[:display_name]} (#{user[:id]})
          #{user[:email]} #{user[:product]}
          Followers: #{user[:followers][:total]}
        TEXT
      end
    end
  end
end
