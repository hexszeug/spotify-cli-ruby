# frozen_string_literal: true

module Main
  module DefCmd
    class << self
      ##
      # @return [Command::Dispatcher]
      def create
        @dispatcher = Command::Dispatcher.new
        Exit.new(@dispatcher)
        Echo.new(@dispatcher)
        Account.new(@dispatcher)
        TopItems.new(@dispatcher)
        Search.new(@dispatcher)
      end

      def execute(str)
        # @todo rescue exceptions raised in execute commands
        @dispatcher.execute(str)
      rescue Command::CommandError => e
        UI.print(e.message)
      end

      def suggest(str)
        # @todo rescue [Command::CommandError] and report to suggestions
        @dispatcher.suggest(str)
      end
    end
  end
end

require_relative 'def_cmd/utils'

require_relative 'def_cmd/exit'
require_relative 'def_cmd/echo'
require_relative 'def_cmd/account'
require_relative 'def_cmd/top_items'
require_relative 'def_cmd/search'
