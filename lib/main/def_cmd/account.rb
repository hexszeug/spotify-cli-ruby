# frozen_string_literal: true

module Main
  module DefCmd
    class Account
      include Command
      include UI::PrintUtils

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
        print[:info].create(<<~TEXT)
          Fetching user info.$~.
        TEXT
        Spotify::API::Users.get_current_users_profile do |user|
          print[:info].replace(user, type: Display::User::Details)
        end.error do |e|
          print[:info].replace(e, type: Display::Error)
        end
      end

      def load
        Spotify::Auth::Token.load
        print <<~TEXT
          Loaded login data. Type `me` to see your account info.
          $%(You do not need to do this manually. Data is loaded every time you start the program.)$%
        TEXT
      rescue Spotify::Auth::Token::NoTokenError,
             Spotify::Auth::Token::TokenParseError => e
        print e, type: Display::Error
      end

      def save
        Spotify::Auth::Token.save
        print <<~TEXT
          Saved login data.
          $%(You do not need to do this manually. Data is saved every time you quit the program.)$%
        TEXT
      rescue Spotify::Auth::Token::NoTokenError => e
        print e, type: Display::Error
      end

      def refresh
        print[:refresh].create(<<~TEXT)
          Refreshing token.$~.
        TEXT
        Spotify::Auth::Token.refresh do
          print[:refresh].replace(<<~TEXT)
            Refreshed token.
          TEXT
        end.error do |e|
          print[:refresh].replace(e, type: Display::Error)
        end
      end

      def login(force: false)
        cancel_login if force && @login
        if @login
          print <<~TEXT
            You are already loggin in.
            Type `login cancel` if you want to cancel the login process or `login force` if you want to cancel and restart the login.
          TEXT
          return
        end
        if !force && Spotify::Auth::Token.get
          print <<~TEXT
            You are already logged in.
            Type `login force` if you want to logout the current account and login a new one.
          TEXT
          return
        end

        print <<~TEXT
          Login started.
        TEXT
        print[:login].create(<<~TEXT)
          A browser window should pop up.
        TEXT
        @login = Spotify::Auth.login do
          @login = nil
          print[:login].replace(<<~TEXT)
            You successfully logged in.
          TEXT
        end.error do |e|
          print[:login].replace(e, type: Display::Error)
        end
      end

      def cancel_login
        unless @login
          print <<~TEXT
            You are not logging in. There is nothing to cancel.
          TEXT
          return
        end
        @login.cancel
        @login = nil
        print[:login].replace(<<~TEXT)
          Canceled login.
        TEXT
      end

      def logout
        Spotify::Auth::Token.set(nil)
        print <<~TEXT
          Successfully logged out.
        TEXT
      end
    end
  end
end
