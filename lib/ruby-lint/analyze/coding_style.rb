module RubyLint
  module Analyze
    ##
    # {RubyLint::Analyze::CodingStyle} checks if a block of code matches a given
    # set of coding standards. While none of the problems found by this class
    # are considered harmful they are usually frowned upon as they do not
    # follow the unofficial but generally accepted Ruby coding standards.
    #
    # ## Standards References
    #
    # The following was used to determine the standards this class should
    # assume to be correct:
    #
    # * https://github.com/styleguide/ruby
    # * https://github.com/bbatsov/ruby-style-guide
    # * http://confluence.jetbrains.net/display/RUBYDEV/RubyMine+Inspections
    # * My own opinion
    #
    # ## Checks
    #
    # This class checks for the following:
    #
    # * The length of method and variable names, should be less than the value
    #   set in {RubyLint::Analyze::CodingStyle::MAXIMUM\_NAME\_LENGTH}.
    # * The use of class variables (it's relatively rare that you actually need
    #   those).
    # * The use of parenthesis around various statements: these are not needed
    #   in Ruby.
    # * The use of camelCase for method and variable names instead of
    #   `snake_case`, the latter is what Ruby code should use.
    # * Whether or not predicate methods are named correctly.
    # * If a particular method name should be replaced by a different one (e.g.
    #   "map" instead of "collect").
    #
    class CodingStyle < RubyLint::Callback
      ##
      # A short description of this class.
      #
      # @return [String]
      #
      DESCRIPTION = 'Checks the coding style of a block of code.'

      ##
      # The maximum length for method and variable names.
      #
      # @return [Fixnum]
      #
      MAXIMUM_NAME_LENGTH = 30

      ##
      # Hash containing the names of method names and the names that should be
      # used instead.
      #
      # @return [Hash]
      #
      RECOMMENDED_METHOD_NAMES = {
        'collect'  => 'map',
        'detect'   => 'find',
        'find_all' => 'select',
        'inject'   => 'reduce',
        'length'   => 'size'
      }

      ##
      # @see RubyLint::Callback#initialize
      #
      def initialize(*args)
        super

        @in_method        = false
        @predicate_method = false
      end

      ##
      # Called when an instance variable is found.
      #
      # The following checks are run for instance variables:
      #
      # * Whether or not instance variables are `snake_cased` instead of
      #   camelCased.
      # * Whether or not the length of an instance variable is smaller than the
      #   value defined in {RubyLint::Analyze::CodingStyle::MAXIMUM\_NAME\_LENGTH}.
      #
      # @param [RubyLint::Token::VariableToken] token The token containing details
      #  about the variable.
      #
      def on_instance_variable(token)
        validate_name(token)
      end

      ##
      # Called when a class variable is found.
      #
      # This method will check for the same things as
      # {RubyLint::Analyze::CodingStyle#on_instance_variable} along with adding an
      # info message about class variables being discouraged.
      #
      # @see RubyLint::Analyze::CodingStyle#on_instance_variable
      #
      def on_class_variable(token)
        validate_name(token)

        info(
          'the use of class variables is discouraged',
          token.line,
          token.column
        )
      end

      ##
      # Called when a constant is found.
      #
      # @see RubyLint::Analyze::CodingStyle#on_instance_variable
      #
      def on_constant(token)
        validate_name_length(token)
      end

      ##
      # Called when a global variable is found.
      #
      # @see RubyLint::Analyze::CodingStyle#on_instance_variable
      #
      def on_global_variable(token)
        validate_name(token)
      end

      ##
      # Called when an instance variable is found.
      #
      # @see RubyLint::Analyze::CodingStyle#on_instance_variable
      #
      def on_local_variable(token)
        validate_name(token)
      end

      ##
      # Called when a value is assigned.
      #
      # This method checks for the name of the used variable (similar to
      # instance variables) as well as adding a warning when an instance
      # variable is assigned.
      #
      # @see RubyLint::Analyze::CodingStyle#on_instance_variable
      # @see RubyLint::Analyze::CodingStyle#on_class_variable
      #
      def on_assignment(token)
        validate_name(token)

        if token.type == :class_variable
          info(
            'the use of class variables is discouraged',
            token.line,
            token.column
          )
        end
      end

      ##
      # Called when a return statement is found.
      #
      # @param [RubyLint::Token::StatementToken] token The token of the return
      #  statement.
      #
      def on_return(token)
        if !token.value or token.value.empty? or !@in_method
          return
        end

        token.value.each do |value|
          # TODO: this probably won't work very well if there's a lambda inside
          # a method that returns `true` or `false`.
          if value.type == :keyword \
          and (value.name == 'true' or value.name == 'false')
            @predicate_method = true

            break
          end
        end
      end

      ##
      # Called when a method is defined. This method validates the name similar
      # to instance variables as well as checking if the method definition
      # modifies a core Ruby constant.
      #
      # @see RubyLint::Analyze::CodingStyle#on_instance_variable
      #
      def on_method_definition(token)
        validate_name(token)

        if token.receiver
          validate_ruby_constant_modification(token.receiver)
        end

        @in_method = true
      end

      ##
      # Called when a class is created. This callback adds a warning if a core
      # Ruby constant is modified.
      #
      # @param [RubyLint::Token::ClassToken] token Token class containing details
      #  about the newly created class.
      #
      def on_class(token)
        validate_ruby_constant_modification(token)
      end

      ##
      # Called after a method token has been processed. This callback checks if
      # a method is a predicate method and if so if the name is set correctly.
      #
      # @param [RubyLint::Token::MethodDefinitionToken] token The token containing
      #  details about the method definition.
      # @todo This method currently only performs a very limited check for
      #  predicate methods. Once a proper scoping system has been implemented
      #  this method should be updated accordingly.
      #
      def after_method_definition(token)
        if @predicate_method and token.name !~ /\?$/
          info(
            'predicate methods should end with a question mark',
            token.line,
            token.column
          )
        end

        @in_method        = false
        @predicate_method = false
      end

      ##
      # Called when a method call is found.
      #
      # This method checks if the used method should be named differently
      # instead (e.g. "map" instead of "collect").
      #
      # @param [RubyLint::Token::MethodToken] token Token containing details about
      #  the method.
      #
      def on_method(token)
        if RECOMMENDED_METHOD_NAMES.key?(token.name)
          recommended = RECOMMENDED_METHOD_NAMES[token.name]

          info(
            'it is recommended to use the method "%s" instead of "%s"' % [
              recommended,
              token.name
            ],
            token.line,
            token.column
          )
        end
      end

      ##
      # Called when an if statement is found.
      #
      # This method checks to see if there are any parenthesis around the
      # statement and adds an info message if this is the case.
      #
      # @param [RubyLint::Token::StatementToken] token The token containing
      #  details about the if statement.
      #
      def on_if(token)
        validate_parenthesis(token)
      end

      ##
      # Called when an elsif statement is found.
      #
      # @see RubyLint::Analyze::CodingStyle#on_if
      #
      def on_elsif(token)
        validate_parenthesis(token)
      end

      ##
      # Called when a while statement is found.
      #
      # @see RubyLint::Analyze::CodingStyle#on_if
      #
      def on_while(token)
        validate_parenthesis(token)
      end

      ##
      # Called when a case statement is found.
      #
      # @see RubyLint::Analyze::CodingStyle#on_if
      #
      def on_case(token)
        validate_parenthesis(token)
      end

      ##
      # Called when a when statement is found.
      #
      # @see RubyLint::Analyze::CodingStyle#on_if
      #
      def on_when(token)
        validate_parenthesis(token)
      end

      ##
      # Called when an until statement is found.
      #
      # @see RubyLint::Analyze::CodingStyle#on_if
      #
      def on_until(token)
        validate_parenthesis(token)
      end

      ##
      # Called when an unless statement is found.
      #
      # @see RubyLint::Analyze::CodingStyle#on_if
      #
      def on_unless(token)
        validate_parenthesis(token)
      end

      private

      ##
      # Validates the name of the specified token. This method will check for
      # the use of camelCase as well as checking for the length of the name.
      #
      # @param [RubyLint::Token::Token] token The token to validate.
      #
      def validate_name(token)
        if !token.respond_to?(:name) or !token.name
          return
        end

        if token.name =~ /[a-z]+[A-Z]+/
          info(
            'the use of camelCase for names is discouraged',
            token.line,
            token.column
          )
        end

        validate_name_length(token)
      end

      ##
      # Checks if the name of the given token is too long or not. The maximum
      # length of names is set in
      # {RubyLint::Analyze::CodingStyle::MAXIMUM\_NAME\_LENGTH}.
      #
      # @param [RubyLint::Token::Token] token The token to validate.
      #
      def validate_name_length(token)
        if !token.respond_to?(:name) or !token.name
          return
        end

        if token.name.length > MAXIMUM_NAME_LENGTH
          info(
            "method and variable names should not be longer than " \
              "#{MAXIMUM_NAME_LENGTH} characters",
            token.line,
            token.column
          )
        end
      end

      ##
      # Checks if there are any parenthesis wrapped around a statement.
      #
      # @param [RubyLint::Token::Token] token The token to validate.
      #
      def validate_parenthesis(token)
        if token.code =~ /#{token.type}\s*\(/
          info(
            'the use of parenthesis for statements is discouraged',
            token.line,
            token.column
          )
        end
      end

      ##
      # Adds a warning for modifying a core Ruby constant.
      #
      # @param [RubyLint::Token::Token] token The token class to validate.
      #
      def validate_ruby_constant_modification(token)
        if token.name.is_a?(Array)
          name = token.name.join('::')
        else
          name = token.name
        end

        if Object.constants.include?(name.to_sym)
          warning(
            'modification of a core Ruby constant',
            token.line,
            token.column
          )
        end
      end
    end # CodingStyle
  end # Analyze
end # RubyLint
