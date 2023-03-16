module Spotify
  class AuthError < SpotifyError
  end

  class Auth::TokenError < AuthError
  end

  # superclass for login errors
  class Auth::LoginError < AuthError
  end

  module Auth::Login
    # raised by Login.new_token when login prompt in browser cannot be opened
    class OpenUserPromptError < Auth::LoginError
    end

    # raised by CodeServer.start when the system call to open the socket fails
    class OpenCodeServerError < Auth::LoginError
      attr_reader :system_call_error

      def initialize(system_call_error)
        @system_call_error = system_call_error
      end
    end

    # raised when authorize endpoint denies request for authorization code
    # for possible reasons https://www.rfc-editor.org/rfc/rfc6749#section-4.1.2.1
    class CodeDeniedError < Auth::LoginError
      attr_reader :error_str

      def initialize(error_str)
        @error_str = error_str
      end
    end
  end

  module Auth::Login::CodeServer
  end
end
