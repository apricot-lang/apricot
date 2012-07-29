module Apricot
  module AST
    # This is a scope with real local variable storage, i.e. it is part of a
    # block of code like a fn or the top level program. Let scopes do not have
    # storage and must ask for storage from one of these.
    module StorageScope
      def variable_names
        @variable_names ||= []
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

    class FnScope
      include StorageScope

      attr_reader :parent, :variables
      attr_accessor :loop_label, :splat
      alias_method :splat?, :splat

      def initialize(parent)
        @parent = parent
        @variables = {}
        @loop_label = nil
        @splat = false
      end

      # An identifier or a nested scope is looking up a variable. If the
      # variable is found here, return a reference to it. Otherwise look it up
      # on the parent and increment its depth because it is beyond the bounds
      # of the current block of code (fn).
      def find_var(name)
        if var = @variables[name]
          var.reference
        else
          var = @parent.find_var(name)
          var.depth += 1
          var
        end
      end

      # Create a new local on the current level.
      def new_local(name)
        @variables[name] = store_new_local(name)
      end
    end

    # The let scope doesn't have real storage for locals. It stores its locals
    # on the nearest enclosing real scope, which is any separate block of code
    # such as a fn, defn, defmacro or the top level of the program.
    class LetScope
      attr_reader :parent, :variables
      attr_accessor :loop_label
      alias_method :loop?, :loop_label

      def initialize(parent)
        @parent = parent
        @variables = {}
        @loop_label = nil
      end

      # An identifier or a nested scope is looking up a variable.
      def find_var(name)
        if var = @variables[name]
          var.reference
        else
          @parent.find_var(name)
        end
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
