module Command
    class CommandDispatcher
        def initialize
            @root = CommandNode.new :root, ''
        end

        def register node
            @root.then node #TODO catch build errors
            #TODO run ambiguity checks (or put them elsewere)
            # 1. cannot decide which argument node to take
            # 2. duplicate argument names in single branch
        end

        def execute str
            cmd = str.split ' ', -1 #TODO handle consecutive spaces
            context = CommandContext.new cmd
            @root.dispatch context
            context.last_tracked.execute context
        end
    end

    def literal literal
        CommandNode.new :literal, literal
    end

    def argument name
        CommandNode.new :argument, name
    end

    class CommandNode
        def initialize type, name
            case type
            when :root
                unless name == ''
                    raise ArgumentError.new 'name of root must be empty string'
                end
            when :literal
                name = name.to_s
                unless name =~ /^\S+$/
                    raise ArgumentError.new "name of literal cannot contain whitespaces"
                end
            when :argument
                name = name.to_s unless name.is_a? Symbol
            else
                raise ArgumentError.new "#{type} is not a command node type"
            end
            if type != :root && name == ''
                raise ArgumentError.new 'name of non root notes cannot be empty sting'
            end
            @type = type
            @name = name
            @literal_children = {}
            @argument_children = {}
            @executer = nil
        end

        # getter

        def type
            @type
        end

        def name
            @name
        end

        # to be overridden
        def display_name
            case @type
            when :literal
                @name
            when :argument
                "<#{@name.to_s}>"
            else
                ''
            end
        end

        # parsing, suggesting and executing methods

        # to be overridden
        def valid? token
            true
        end

        # to be overridden
        def parse token
            token
        end

        def dispatch context
            # track and parse self
            unless @type == :root
                context.track_node self
                if @type == :argument
                    context[@name] = parse context.last_tracked_token
                end
            end
            # dispatch to next node
            token = context.first_untracked_token
            unless token
                return if @executer
                raise ParsingError.new :missing_args, context
            end
            node = @literal_children[token]
            if node
                node.dispatch context
                return
            end
            @argument_children.each_value do |node|
                if node.valid? token
                    node.dispatch context
                    return
                end
            end
            raise ParsingError.new :incorrect_args, context
        end

        def execute?
            @executer.is_a? Proc
        end

        def execute context
            unless context.valid?
                raise ParsingError.new :invalid_context, context
            end
            @executer.call context
        end

        # building methods

        def then node
            case node.type
            when :root
                raise BuildingError.new 'cannot add root nodes as children'
            when :literal
                @literal_children[node.name] = node
            when :argument
                @argument_children[node.name] = node
            end
            self
        end

        def remove node_name
            @literal_children.remove node_name
            @argument_children.remove node_name
            self
        end

        def executes &executer
            @executer = executer
            self
        end
    end

    class CommandContext
        def initialize cmd
            @cmd = cmd
            @nodes = []
            @args = {}
        end

        def [] arg_name
            @args[arg_name]
        end

        def []= arg_name, arg
            @args[arg_name] = arg
        end

        def cmd
            @cmd
        end

        def nodes
            @nodes
        end

        def last_tracked
            @nodes.last
        end

        def last_tracked_token
            return nil if @nodes.empty?
            @cmd[@nodes.length - 1]
        end

        def first_untracked_token
            @cmd[@nodes.length]
        end

        def valid?
            @nodes.length == @cmd.length && @nodes.last.execute?
        end

        def track_node node
            @nodes.push node
        end
    end

    class CommandError < StandardError
        def initialize msg
            super msg
            @msg = msg
        end

        def msg
            @msg
        end
    end
    
    class BuildingError < CommandError
        def initialize type #TODO
        end
    end

    class ParsingError < CommandError
        def initialize type, context
            cmd_str = context.cmd * ' '
            cmd_snippet = -> (length, cmd: nil) do
                cmd = cmd_str unless cmd
                cmd.length <= length ? cmd : '...' + cmd[-length..-1]
            end
            case type
            when :incorrect_args
                super "not matching argument: #{cmd_snippet.call 15}<--HERE"
            when :missing_args
                super "incomplete command: #{cmd_snippet.call 15}<--HERE"
            when :invalid_context
                super "tried executing improperly parsed command. this is a bug and should not happen. please report"
            when :invalid_token
                super "malformed argument #{context.last_tracked.display_name}: #{cmd_snippet.call 15, cmd: context.cmd[0...context.nodes.length] * ' '}<--HERE"
            else
                super type
            end
            @type = type
            @context = context
        end

        def type
            @type
        end

        def context
            @context
        end
    end
end