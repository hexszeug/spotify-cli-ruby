module Main
  module DefCmd
    class Login
      include Command

      def initialize(dispatcher)
        dispatcher.register(
          literal('login').executes do
            login
          end.then(
            literal('cancel').executes do
              cancel
            end
          ).then(
            literal('force').executes do
              cancel if @promise
              login(force: true)
            end
          )
        )
      end

      private

      def cancel
        unless @promise
          UI.print <<~TEXT
            There is no login process running.
          TEXT
          return
        end
        @promise.cancel
        @promise = nil
        UI.print <<~TEXT
          Canceled login.
        TEXT
      end

      def login(force: false)
        if @promise
          UI.print <<~TEXT
            You are already loggin in.
            Type `login cancel` if you want to cancel the login process or `login force` if you want to cancel and restart the login.
          TEXT
          return
        end
        if !force && Spotify::Auth::Token.get
          UI.print <<~TEXT
            You are already logged in.
            Type `login force` if you want to logout the current user.
          TEXT
          return
        end

        UI.print <<~TEXT
          Login started. A browser window should pop up.
        TEXT
        @promise = Spotify::Auth.login do
          success
        end.error do |e|
          error(e)
        end
      end

      def success
        @promise = nil
        UI.print <<~TEXT
          You successfully logged in.
        TEXT
      end

      def error(error)
        @promise = nil
        UI.print <<~TEXT
          An error occured:
          #{error}
        TEXT
      end
    end
  end
end
