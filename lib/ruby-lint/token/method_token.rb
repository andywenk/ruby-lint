module RubyLint
  module Token
    ##
    # Token class used for storing methods, their parameters, body, etc.
    #
    # @since 2012-07-29
    #
    class MethodToken < Token
      ##
      # The receiver of the method call, if any.
      #
      # @return [RubyLint::Token::Token]
      #
      attr_accessor :receiver

      ##
      # Symbol containing the method separator, if any.
      #
      # @return [Symbol]
      #
      attr_accessor :operator

      ##
      # Array of tokens for the method parameters.
      #
      # @return [Array]
      #
      attr_accessor :parameters

      ##
      # Token containing details about the block passed to the method.
      #
      # @return [RubyLint::Token::BlockToken]
      #
      attr_accessor :block

      ##
      # @see RubyLint::Token::Token#initialize
      #
      def initialize(*args)
        @type = :method

        super

        @parameters = [] unless @parameters
      end

      ##
      # @see RubyLint::Token::Token#child_nodes
      #
      def child_nodes
        return super << @parameters << [@receiver] << [@block]
      end
    end # MethodToken
  end # Token
end # RubyLint
