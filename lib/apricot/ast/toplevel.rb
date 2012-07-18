module Apricot
  module AST
    class TopLevel < Node
      attr_reader :elements, :file

      def initialize(elements, file)
        @elements = elements
        @file = file
        @line = 1
        @variable_names = []
      end

      def bytecode(g)
        g.name = :__top_level__
        g.file = @file.to_sym

        g.push_state self

        pos(g)
        SpecialForm[:do].bytecode(g, @elements)
        g.ret

        g.pop_state

        g.local_count = local_count
        g.local_names = local_names
      end

      # A nested scope is looking up a variable. There are no local variables
      # at the top level, so look up the variable on the current namespace.
      def find_var(name)
        # TODO: look up variable on the current namespace
        raise "Could not find var: #{name}"
      end

      def store_new_local(name)
        variable = Compiler::LocalVariable.new next_slot
        @variable_names << name
        variable
      end

      def next_slot
        @variable_names.size
      end

      def local_count
        @variable_names.size
      end

      def local_names
        @variable_names
      end
    end
  end
end
