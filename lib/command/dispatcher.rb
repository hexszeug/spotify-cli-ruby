# frozen_string_literal: true

module Command
  class Dispatcher
    def initialize
      @root = Node.new(:root, '')
    end

    def register(node)
      @root.then(node)
    end

    ##
    # @raise [CommandError]
    def suggest(str)
      begin
        context = parse(str)
        node = context.last_tracked
        complete_token = context.last_tracked_token
      rescue CommandError => e
        context = e.context
        case e.type
        when :missing_arg # "<--HERE" / "command<--HERE"
          node = context.nodes[-2]
          complete_token = context.last_tracked_token
        when :incorrect_arg # "command jdkslfj<--HERE" / "command <--HERE"
          node = context.last_tracked
          complete_token = context.first_untracked_token
          raise e unless context.nodes.length + 1 == context.cmd.length
        else
          raise e
        end
      end
      node ||= @root
      complete_token ||= ''
      sugs = node.suggest(context)
      sugs.filter! { |sug| sug.start_with?(complete_token) }
      if sugs.empty?
        raise e if e

        node.parse(node) unless node.valid?(node)
      end
      sugs.sort
    end

    def execute(str)
      context = parse(str)
      context.last_tracked.execute(context)
    end

    private

    def parse(str)
      cmd = str.split(/\s/, -1)
      context = Context.new(cmd)
      @root.dispatch(context)
      context
    end
  end
end
