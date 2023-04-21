# Spotify CLI (made with ruby)

Useless command line interface (CLI) which can control your Spotify playback but doesn't support streaming audio.
It's just a proof of concept and it's main purpose is learning from the developement.

***Disclaimer:***  
*The project is still kind of work in progress. I just paused developement for an indefinte amount of time.*

## Running it

There is no single executeable or something like that so the only option is running it in a developement environment.
Also it's not tested to run on all platforms.
I used WSL on Windows 10 with Ubuntu 22.04.2 LTS for developement.

### Dependencies

You need the following dependencies on your local machine:
* ruby 3.2.1 or higher
* ncursesw (maybe other curses implementations like PDCurses work aswell but I tested just ncursesw)
* bundler 2.4.7 or higher (install via `gem install bundler`)
* all gems in the Gemfile (just run `bundler install` once you are in the main directory of the repo)

### Spotify app

Spotify only allows a limited amount of Spotify accounts to access the API via one client id and secret.
Thus you need to create your own Spotify app on the dashboard to get your own client id and secret and access the API.
To do so follow these simple steps:
1. Go to the [dashboard](https://developer.spotify.com/dashboard) and login with your Spotify account (if you're not already logged in).
2. Click the Create app button.
3. Enter any name and description you want (for example `Ruby CLI by hexszeug`).
4. Paste `http://localhost:8888/callback/` into the Redirect URI field. **Not the Website field!**
5. Tick the agreement box and save the app.
6. You can find the client id and secret in the setting of the app. Replace the corresponding constants in lib/spotify/auth.rb with your values.

### Running the CLI

Running is now realy simple. The only thing you have to do is navigate into the root directory of the repo and run `ruby ruby_script.rb`.

A fullscreen application will take controll of your terminal and you can just start typing commands. At first you will need to login with your Spotify account via the `login` command. After that feel free to explore the commands via the auto-completion (triggered by tab).
*P.S. use ctrl + arrows for scrolling. everything else should be intuitive*