module Apricot
  module AST
    # The let scope doesn't have real storage for locals. It stores its locals
    # on the nearest enclosing real scope, which is any separate block of code
    # such as a fn, defn, defmacro or the top level of the program.
    class LetScope < Node
      attr_accessor :parent

      def initialize
        @variables = {}
      end

      # A nested scope is looking up a variable.
      def find_var(name)
        @variables[name] || @parent.find_var(name)
      end

      # Create a new local on the current level, with storage on the nearest
      # enclosing real scope.
      def new_local(name)
        @variables[name] = @parent.store_new_local(name)
      end

      # A deeper let is asking for a new local slot. Pass it along to the
      # parent so it eventually reaches a real scope.
      def store_new_local(name)
        @parent.store_new_local(name)
      end
    end
  end
end
