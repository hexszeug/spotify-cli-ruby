# frozen_string_literal: true

module Command
  module Arguments
    class GreedyString < Node
      def initialize(name)
        super(:argument, name)
      end

      def <=>(other)
        other.instance_of?(GreedyString) ? 0 : 1
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

    class Integer < Node
      def initialize(name)
        super(:argument, name)
      end

      def valid?(token)
        token.match?(/^\d+$/)
      end

      def parse(token)
        token.to_i
      end
    end
  end
end
