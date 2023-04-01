# frozen_string_literal: true

module Command
  class Node
    attr_reader :type, :name

    def initialize(type, name)
      case type
      when :root
        unless name == ''
          raise ArgumentError, 'name of root must be empty string'
        end
      when :literal
        name = name.to_s
        if /\s/ =~ name
          raise ArgumentError,
                'name of literal cannot contain whitespaces'
        end
      when :argument
        name = name.to_s unless name.is_a? Symbol
      else
        raise ArgumentError, "#{type} is not a command node type"
      end
      if type != :root && name == ''
        raise ArgumentError,
              'name of non root notes cannot be empty sting'
      end

      @type = type
      @name = name
      @literal_children = {}
      @argument_children = {}
      @executer = nil
      @suggester = nil
    end

    # @todo implement comparison function, use it for building and dispatching

    ##
    # *to be overridden*
    #
    # @return [String] display name
    def display_name
      case @type
      when :literal
        @name
      when :argument
        "<#{@name}>"
      else
        ''
      end
    end

    ##
    # *to be overridden*
    #
    # @return [Boolean] if token is valid argument
    def valid?(token)
      case @type
      when :literal then @name == token
      when :argument then true
      else false
      end
    end

    ##
    # *to be overridden*
    #
    # @return [Object] parsed token
    def parse(token)
      token
    end

    ### dispatching methods

    ##
    # @return [nil]
    def dispatch(context)
      # track and parse self
      unless @type == :root
        context.track_node(self)
        if @type == :argument
          context[@name] =
            parse(context.last_tracked_token)
        end
      end
      # detect command ending
      token = context.first_untracked_token
      unless token
        return if @executer

        raise CommandError.new(:missing_arg, context)
      end
      # dispatch to next node
      # dispatch to literal if matching
      if (node = @literal_children[token])
        node.dispatch(context)
        return
      end
      # dispatch to argument (match sub classes before classes)
      arg =
        @argument_children
        .values
        .filter { |a| a.valid? token }
        .min { |a, b| a.class <=> b.class }
      if arg
        arg.dispatch(context)
        return
      end
      raise CommandError.new(:incorrect_arg, context)
    end

    ### suggesting methods

    ##
    # @return [Array] suggestion
    def suggest(context)
      res = []
      @literal_children.each_value do |node|
        res += node.list_suggestions(context)
      end
      @argument_children.each_value do |node|
        res += node.list_suggestions(context)
      end
      res
    end

    ##
    # @return [Array] suggestions
    def list_suggestions(context)
      return [@name] if @type == :literal
      return [] if @suggester.nil?

      @suggester.call(context)
    end

    ### executing methods

    ##
    # @return [Boolean]
    def execute?
      !@executer.nil?
    end

    ##
    # @raise [CommandError] when context is invalid
    def execute(context)
      unless context.valid?
        raise CommandError.new(
          :invalid_context,
          context
        )
      end

      @executer.call(context)
    end

    ### building methods

    ##
    # @return [Node] self
    def then(node)
      raise BuildingError.new(:not_a_node, self, node) unless node.is_a?(Node)

      case node.type
      when :root
        raise BuildingError.new(:child_root, self, node)
      when :literal
        if @literal_children[node.name]
          raise BuildingError.new(
            :duplicate_names,
            self,
            node,
            @literal_children[node.name]
          )
        end
        @literal_children[node.name] = node
      when :argument
        if @argument_children[node.name]
          raise BuildingError.new(
            :duplicate_names,
            self,
            node,
            @argument_children[node.name]
          )
        end
        @argument_children.each_value do |arg|
          next unless arg.instance_of? node.class

          raise BuildingError.new(
            :indistinguishable_arguments,
            self,
            node,
            arg
          )
        end
        @argument_children[node.name] = node
      end
      self
    end

    ##
    # @return [Node] self
    def suggests(&block)
      @suggester = block
      self
    end

    ##
    # @return [Node] self
    def executes(&block)
      @executer = block
      self
    end
  end
end
