module Command
    def literal(literal)
        CommandNode.new :literal, literal
    end

    def argument(name)
        CommandNode.new :argument, name
    end

    class CommandNode
        def initialize(type, name)
            case type
            when :root
                unless name == ""
                    raise ArgumentError.new "name of root must be empty string"
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
            if type != :root && name == ""
                raise ArgumentError.new "name of non root notes cannot be empty sting"
            end
            @type = type
            @name = name
            @literal_children = {}
            @argument_children = {}
            @executer = nil
            @suggester = nil
        end

        ### getter

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
                ""
            end
        end

        ### building methods

        def then(node)
            unless node.is_a? CommandNode
                raise BuildingError.new :not_a_node, self, node
            end
            case node.type
            when :root
                raise BuildingError.new :child_root, self, node
            when :literal
                if @literal_children[node.name]
                    raise BuildingError.new :duplicate_names,
                                                                    self,
                                                                    node,
                                                                    @literal_children[node.name]
                end
                @literal_children[node.name] = node
            when :argument
                if @argument_children[node.name]
                    raise BuildingError.new :duplicate_names,
                                                                    self,
                                                                    node,
                                                                    @argument_children[node.name]
                end
                @argument_children.each_value do |arg|
                    if arg.instance_of? node.class
                        raise BuildingError.new :indistinguishable_arguments,
                                                                        self,
                                                                        node,
                                                                        arg
                    end
                end
                @argument_children[node.name] = node
            end
            self
        end

        def suggests(&suggester)
            @suggester = suggester
            self
        end

        def executes(&executer)
            @executer = executer
            self
        end

        ### parsing methods

        # to be overridden
        def valid?(token)
            true
        end

        # to be overridden
        def parse(token)
            token
        end

        def dispatch(context)
            # track and parse self
            unless @type == :root
                context.track_node self
                context[@name] = parse context.last_tracked_token if @type == :argument
            end
            # detect command ending
            token = context.first_untracked_token
            unless token
                return if @executer
                raise ParsingError.new :missing_arg, context
            end
            # dispatch to next node
            # dispatch to literal if matching
            if node = @literal_children[token]
                node.dispatch context
                return
            end
            # dispatch to argument (match sub classes before classes)
            arg =
                @argument_children
                    .values
                    .filter { |a| a.valid? token }
                    .sort { |a, b| a.class <=> b.class }
                    .first
            if arg
                arg.dispatch context
                return
            end
            raise ParsingError.new :incorrect_arg, context
        end

        ### suggesting methods

        def list_suggestions(context)
            return [@name] if @type == :literal
            return [] unless @suggester.is_a? Proc
            @suggester.call context
        end

        def suggest(context)
            res = []
            @literal_children.each_value do |node|
                res += node.list_suggestions context
            end
            @argument_children.each_value do |node|
                res += node.list_suggestions context
            end
            res
        end

        ### executing methods

        def execute?
            @executer.is_a? Proc
        end

        def execute(context)
            raise ParsingError.new :invalid_context, context unless context.valid?
            @executer.call context
        end
    end

    class CommandDispatcher
        def initialize
            @root = CommandNode.new :root, ""
        end

        def register(node)
            @root.then node
        end

        def suggest(str)
            begin
                context = parse str
                node = context.last_tracked
                complete_token = context.last_tracked_token
            rescue ParsingError => e
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
            node = @root unless node
            complete_token = "" unless complete_token
            sugs = node.suggest(context)
            sugs.filter! { |sug| sug.start_with? complete_token }
            if sugs.empty?
                raise e if e
                node.parse node unless node.valid? node
            end
            sugs.sort
        end

        def execute(str)
            context = parse str
            context.last_tracked.execute context
        end

        private

        def parse(str)
            cmd = str.split /\s/, -1
            context = CommandContext.new cmd
            @root.dispatch context
            context
        end
    end

    class CommandContext
        def initialize(cmd)
            @cmd = cmd
            @nodes = []
            @args = {}
        end

        def [](arg_name)
            @args[arg_name]
        end

        def []=(arg_name, arg)
            if a = @args[arg_name]
                if a.instance_of? Array
                    a.push arg
                else
                    @args[arg_name] = [a, arg]
                end
            else
                @args[arg_name] = arg
            end
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

        def track_node(node)
            @nodes.push node
        end
    end

    class BuildingError < ScriptError
        def initialize(type, parent, *nodes)
            case type
            when :child_root
                super "cannot add root node #{nodes[0].display_name} to #{parent.display_name}"
            when :duplicate_names
                super "#{parent.display_name} already has a note named #{nodes[1].display_name}"
            when :indistinguishable_arguments
                super "parser cannot distinguish between #{node[1].display_name} and #{node[0].display_name} (cannot be added to #{parent.display_name})"
            when :not_a_node
                super "#{nodes[0]} is not a node"
            end
        end
    end

    class CommandError < StandardError
        def initialize(msg)
            super msg
            @msg = msg
        end

        def msg
            @msg
        end
    end

    class ParsingError < CommandError
        def initialize(type, context)
            cmd_str = context.cmd * " "
            cmd_snippet = ->(length, cmd: nil) do
                cmd = cmd_str unless cmd
                cmd.length <= length ? cmd : "..." + cmd[-length..-1]
            end
            case type
            when :incorrect_arg
                super "not matching argument: #{cmd_snippet.call 15}<--HERE"
            when :missing_arg
                super "incomplete command: #{cmd_snippet.call 15}<--HERE"
            when :invalid_context
                super "tried executing improperly parsed command. this is a bug and should not happen. please report"
            when :invalid_token
                super "malformed argument #{context.last_tracked.display_name}: #{cmd_snippet.call 15, cmd: context.cmd[0...context.nodes.length] * " "}<--HERE"
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
