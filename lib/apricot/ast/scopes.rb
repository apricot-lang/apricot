module Apricot
  module AST
    module TopLevelScope
      def variable_names
        @variable_names ||= []
      end

      # A nested scope is looking up a variable. There are no local variables
      # at the top level, so look up the variable on the current namespace.
      def find_var(name)
        # TODO: look up variable on the current namespace
        raise "Could not find var: #{name}"
      end

      def store_new_local(name)
        variable = Compiler::LocalVariable.new next_slot
        variable_names << name
        variable
      end

      def next_slot
        variable_names.size
      end

      def local_count
        variable_names.size
      end

      def local_names
        variable_names
      end
    end

    # The let scope doesn't have real storage for locals. It stores its locals
    # on the nearest enclosing real scope, which is any separate block of code
    # such as a fn, defn, defmacro or the top level of the program.
    class LetScope
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
