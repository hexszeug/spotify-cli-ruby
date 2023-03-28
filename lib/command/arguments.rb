# frozen_string_literal: true

module Command
  module Arguments
    class GreedyString < Node
      class << self
        def <=>(other)
          return nil unless other < Node

          other == GreedyString ? 0 : -1
        end
      end

      def initialize(name)
        super(:argument, name)
      end

      def display_name
        "[#{@name}]"
      end

      def then(node)
        raise BuildingError.new(:child_of_greedy, self, node)
      end

      def dispatch(context)
        value = []
        (context.cmd.length - context.nodes.length).times do
          context.track_node(self)
          value.push(context.last_tracked_token)
        end
        context[@name] = parse(value.join(' '))
      end
    end
  end
end
