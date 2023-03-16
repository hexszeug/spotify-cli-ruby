# frozen_string_literal: true

require './lib/spotify'

th = Thread.current

promise =
  Spotify::Auth.login do
    puts "successfully received token: #{Spotify::Auth::Token.access_token}"
    th.kill
  end.error do |error|
    th.raise error
  end

gets
promise.cancel
