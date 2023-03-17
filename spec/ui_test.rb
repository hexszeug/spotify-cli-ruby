# frozen_string_literal: true

require './lib/ui'
require './lib/command'

include Command # rubocop:disable Style/MixinUsage

dispatcher = Dispatcher.new
dispatcher.register(
  literal('echo')
      .then(
        Arguments::GreedyString
            .new(:str)
            .executes { |ctx| UI.print { ctx[:str] } }
      )
      .executes { UI.print { '' } }
)
dispatcher.register(
  literal('exit').executes do
    UI.stop_loop
  end
)
UI.returns do |str|
  dispatcher.execute str
  rescue CommandError => e
    UI.print { e.msg }
end

UI.start_loop
