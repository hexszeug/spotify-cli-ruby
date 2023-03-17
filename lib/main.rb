# frozen_string_literal

require_relative 'spotify'
require_relative 'command'
require_relative 'ui'

require_relative 'main/def_cmd'

module Main
end

Main::DefCmd.create
UI.returns { |str| Main::DefCmd.execute(str) }
UI.start_loop
