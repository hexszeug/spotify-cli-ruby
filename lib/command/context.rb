# frozen_string_literal: true

module Command
  class Context
    attr_reader :cmd, :nodes

    def initialize(cmd)
      @cmd = cmd
      @nodes = []
      @args = {}
    end

    def [](arg_name)
      @args[arg_name]
    end

    def []=(arg_name, arg)
      if (a = @args[arg_name])
        if a.instance_of?(Array)
          a.push(arg)
        else
          @args[arg_name] = [a, arg]
        end
      else
        @args[arg_name] = arg
      end
    end

    def last_tracked
      @nodes.last
    end

    def last_tracked_token
      return if @nodes.empty?

      @cmd[@nodes.length - 1]
    end

    def first_untracked_token
      @cmd[@nodes.length]
    end

    def valid?
      (@nodes.length == @cmd.length) && @nodes.last.execute?
    end

    def track_node(node)
      @nodes.push(node)
    end
  end
end
