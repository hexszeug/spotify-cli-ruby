# frozen_string_literal: true

module Main
  module DefCmd
    class Account
      include Command
      include Utils

      def initialize(dispatcher)
        dispatcher.register(
          literal('account').executes do
            info
          end.then(
            literal('load').executes { load }
          ).then(
            literal('save').executes { save }
          ).then(
            literal('refresh').executes { refresh }
          ).then(
            literal('login').executes { login(force: true) }
          ).then(
            literal('logout').executes { logout }
          )
        )
        dispatcher.register(
          literal('me').executes { info }
        )
        dispatcher.register(
          literal('login').executes do
            login
          end.then(
            literal('cancel').executes do
              cancel_login
            end
          ).then(
            literal('force').executes do
              login(force: true)
            end
          )
        )
        dispatcher.register(
          literal('logout').executes { logout }
        )
      end

      private

      def info
        Spotify::API::Users.get_current_users_profile do |user|
          UI.print <<~TEXT
            You are currently logged in as:
            #{explain_user(user)}
          TEXT
        end.error do |e|
          UI.print explain_error(e)
        end
      end

      def load
        Spotify::Auth::Token.load
        UI.print <<~TEXT
          Loaded login data. Type `me` to see your account info.
          (You do not need to do this manually. Data is loaded every time you start the program.)
        TEXT
      rescue Spotify::Auth::Token::NoTokenError,
             Spotify::Auth::Token::TokenParseError => e
        UI.print explain_error(e)
      end

      def save
        Spotify::Auth::Token.save
        UI.print <<~TEXT
          Saved login data.
          (You do not need to do this manually. Data is saved every time you quit the program.)
        TEXT
      rescue Spotify::Auth::Token::NoTokenError => e
        UI.print explain_error(e)
      end

      def refresh
        Spotify::Auth::Token.refresh do
          UI.print <<~TEXT
            Refreshed token.
          TEXT
        end.error do |e|
          UI.print explain_error(e)
        end
      end

      def login(force: false)
        cancel_login if force && @login
        if @login
          UI.print <<~TEXT
            You are already loggin in.
            Type `login cancel` if you want to cancel the login process or `login force` if you want to cancel and restart the login.
          TEXT
          return
        end
        if !force && Spotify::Auth::Token.get
          UI.print <<~TEXT
            You are already logged in.
            Type `login force` if you want to logout the current account and login a new one.
          TEXT
          return
        end

        UI.print <<~TEXT
          Login started. A browser window should pop up.
        TEXT
        @login = Spotify::Auth.login do
          @login = nil
          UI.print <<~TEXT
            You successfully logged in.
          TEXT
        end.error do |e|
          UI.print(explain_error(e))
        end
      end

      def cancel_login
        unless @login
          UI.print <<~TEXT
            You are not logging in. There is nothing to cancel.
          TEXT
          return
        end
        @login.cancel
        @login = nil
        UI.print <<~TEXT
          Canceled login.
        TEXT
      end

      def logout
        Spotify::Auth::Token.set(nil)
        UI.print <<~TEXT
          Successfully logged out.
        TEXT
      end
    end
  end
end
