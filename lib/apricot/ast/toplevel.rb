module Apricot
  module AST
    class TopLevel < Node
      include StorageScope

      attr_reader :elements, :file

      def initialize(elements, file)
        @elements = elements
        @file = file
        @line = 1
      end

      def bytecode(g)
        g.name = :__top_level__
        g.file = @file.to_sym

        g.push_scope self

        pos(g)
        SpecialForm[:do].bytecode(g, @elements)
        g.ret

        g.pop_scope

        g.local_count = local_count
        g.local_names = local_names
      end

      # A nested scope is looking up a variable. There are no local variables
      # at the top level, so look up the variable on the current namespace.
      def find_var(name)
        Compiler::NamespaceVariableReference.new(name)
      end

      def node_equal?(other)
        self.file == other.file && self.elements == other.elements
      end

      def [](*i)
        @elements[*i]
      end

      # A (recur) is looking for a recursion target. Since this is the top
      # level, which has no parent, the lookup has failed.
      def find_recur_target
        raise "No recursion target for recur found"
      end
    end
  end
end
