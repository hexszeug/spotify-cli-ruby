module Command
  def literal(literal)
    Node.new(:literal, literal)
  end

  def argument(name)
    Node.new(:argument, name)
  end

  ##
  # raised by [Dispatcher] #suggest and #execute
  class CommandError < StandardError
    attr_reader :type, :context

    def initialize(type, context)
      super()
      @type = type
      @context = context
    end

    def message
      return @message if @message

      @message =
        case type
        when :incorrect_arg
          "not matching argument: #{cmd_snippet(15)}<--HERE"
        when :missing_arg
          "incomplete command: #{cmd_snippet(15)}<--HERE"
        when :invalid_context
          'tried executing improperly parsed command. ' \
          'this is a bug and should not happen. please report'
        when :invalid_token
          "malformed argument #{@context.last_tracked.display_name}: " \
          "#{cmd_snippet(15, stop_node: @context.nodes.length - 1)}<--HERE"
        else
          @type
        end
    end

    def cmd_snippet(length, stop_node: nil)
      cmd = @context.cmd[..stop_node].join(' ')
      cmd.length > length ? "...#{cmd[-length..]}" : cmd
    end
  end

  ##
  # must not be rescued
  # is raised when an error occures while construction a new command
  class BuildingError < ScriptError
    def initialize(type, parent, *nodes)
      super(
        case type
        when :child_root
          "cannot add root node #{nodes[0].display_name} " \
          "to #{parent.display_name}"
        when :duplicate_names
          "#{parent.display_name} already has a note " \
          "named #{nodes[1].display_name}"
        when :indistinguishable_arguments
          "parser cannot distinguish between #{node[1].display_name} and " \
          "#{node[0].display_name} (cannot be added to #{parent.display_name})"
        when :not_a_node
          "#{nodes[0]} is not a node"
        else
          "#{type} error occured adding #{nodes[0].display_name} " \
          "to #{parent.display_name}"
        end
      )
    end
  end
end

require_relative 'command/node'
require_relative 'command/dispatcher'
require_relative 'command/context'

require_relative 'command/arguments'
