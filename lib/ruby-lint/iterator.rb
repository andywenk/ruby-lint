module RubyLint
  ##
  # {RubyLint::Iterator} is a class that can be used to iterate over the AST
  # generated by {RubyLint::Parser} and execute callback methods for each
  # encountered node. Basic usage is as following:
  #
  #     code = <<-CODE
  #     [10, 20].each do |number|
  #       puts number
  #     end
  #     CODE
  #
  #     parser   = RubyLint::Parser.new(code)
  #     tokens   = parser.parse
  #     iterator = RubyLint::Iterator.new
  #
  #     iterator.run(tokens)
  #
  # This particular example doesn't do anything but iterating over the nodes
  # due to no callback classes being defined. How to add these classes is
  # discussed below.
  #
  # ## Callback Classes
  #
  # Without any custom callback classes the iterator class is fairly useless as
  # it does nothing but iterate over all the nodes. These classes are defined
  # as any ordinary class and are added to an interator instance using
  # {RubyLint::Iterator#bind}. At the most basic level each callback class should
  # have the following structure:
  #
  #     class MyCallback
  #       attr_reader :options
  #
  #       def initialize(report = nil, storage = {})
  #         @report  = report
  #         @storage = storage
  #       end
  #     end
  #
  # The constructor method should take two parameters: the first one is used
  # for storing a instance of {RubyLint::Report} (this parameter should be set to
  # `nil` by default). The second parameter is a Hash containing custom data
  # that is shared between callback classes bound to the same {RubyLint::Iterator}
  # instance. This Hash can be used to share, for example, definitions defined
  # in callback class #1 with callback class #2.
  #
  # To make this, as well as adding errors and such to a report easier your own
  # classes can extend {RubyLint::Callback}:
  #
  #     class MyCallback < RubyLint::Callback
  #
  #     end
  #
  # To add your class to an iterator instance you'd run the following:
  #
  #     iterator = RubyLint::Iterator.new
  #
  #     iterator.bind(MyCallback)
  #
  # ## Callback Methods
  #
  # When iterating over an AST the method {RubyLint::Iterator#iterator} calls two
  # callback methods based on the event name stored in the token (in
  # {RubyLint::Token::Token#event}):
  #
  # * `on_EVENT_NAME`
  # * `after_EVENT_NAME`
  #
  # Where `EVENT_NAME` is the name of the event. For example, for strings this
  # would result in the following methods being called:
  #
  # * `on_string`
  # * `after_string`
  #
  # Note that the "after" callback is not executed until all child nodes have
  # been processed.
  #
  # Each method should take a single parameter that contains details about the
  # token that is currently being processed. Each token is an instance of
  # {RubyLint::Token::Token} or one of its child classes.
  #
  # If you wanted to display the values of all strings in your console you'd
  # write the following class:
  #
  #     class StringPrinter < RubyLint::Callback
  #       def on_string(token)
  #         puts token.value
  #       end
  #     end
  #
  class Iterator
    ##
    # Array containing a set of instance specific callback objects.
    #
    # @return [Array]
    #
    attr_reader :callbacks

    ##
    # Returns the Hash that is used by callback classes to store arbitrary
    # data.
    #
    # @return [Hash]
    #
    attr_reader :storage

    ##
    # Creates a new instance of the iterator class.
    #
    # @param [RubyLint::Report|NilClass] report The report to use, set to `nil` by
    #  default.
    #
    def initialize(report = nil)
      @callbacks = []
      @report    = report
      @storage   = {}
    end

    ##
    # Processes the entire AST for each callback class in sequence. For each
    # callback class the method {RubyLint::Iterator#iterate} is called to process
    # an *entire* AST before moving on to the next callback class.
    #
    # @param [#each] nodes An array of nodes to process.
    #
    def run(nodes)
      @callbacks.each do |obj|
        execute_callback(obj, :on_start)

        iterate(obj, nodes)

        execute_callback(obj, :on_finish)
      end
    end

    ##
    # Processes an AST and calls callbacks methods for a specific callback
    # object.
    #
    # @param [RubyLint::Callback] callback_obj The callback object on which to
    #  invoke callback method.
    # @param [#each] nodes An array (or a different object that responds to
    #  `#each()`) that contains a set of tokens to process.
    #
    def iterate(callback_obj, nodes)
      nodes.each do |node|
        next unless node.is_a?(RubyLint::Token::Token)

        event_name     = node.event.to_s
        callback_name  = 'on_' + event_name
        after_callback = 'after_' + event_name

        execute_callback(callback_obj, callback_name, node)

        node.child_nodes.each do |child_nodes|
          iterate(callback_obj, child_nodes) if child_nodes.respond_to?(:each)
        end

        execute_callback(callback_obj, after_callback, node)
      end
    end

    ##
    # Adds the specified class to the list of callback classes for this
    # instance.
    #
    # @example
    #  iterator = RubyLint::Iterator.new
    #
    #  iterator.bind(CustomCallbackClass)
    #
    # @param [Class] callback_class The class to add.
    #
    def bind(callback_class)
      @callbacks << callback_class.new(@report, @storage)
    end

    private

    ##
    # Loops through all the bound callback classes and executes the specified
    # callback method if it exists.
    #
    # @param [RubyLint::Callback] obj The object on which to invoke the callback
    #  method.
    # @param [String|Symbol] name The name of the callback method to execute.
    # @param [Array] args Arguments to pass to the callback method.
    #
    def execute_callback(obj, name, *args)
      obj.send(name, *args) if obj.respond_to?(name)
    end
  end # Iterator
end # RubyLint
