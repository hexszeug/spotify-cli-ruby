# frozen_string_literal: true

module Main
end

require_relative 'spotify'
require_relative 'command'
require_relative 'ui'

require_relative 'main/def_cmd'
require_relative 'main/context'
require_relative 'main/display'

Spotify::Auth::Token.load(save: true)

Main::DefCmd.create
UI.returns { |str| Main::DefCmd.execute(str) }
UI.suggests { |str| Main::DefCmd.suggest(str) }
UI.on_crash { false }

begin
  UI.start_loop
ensure
  Spotify::Auth::Token.save(save: true)
end
