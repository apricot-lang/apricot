module Apricot
  module AST
    class Identifier < Node
      attr_reader :name

      def initialize(line, name)
        super(line)
        @name = name
      end

      def bytecode(g)
        pos(g)
        g.scope.find_var(name).bytecode(g)
      end

      # called by (def <identifier> <value>)
      def assign_bytecode(g, value)
        g.push_cpath_top
        g.find_const :Apricot
        g.send :current_namespace, 0
        g.push_literal name
        value.bytecode(g)
        g.send :set_var, 2
      end

      def quote_bytecode(g)
        pos(g)

        g.push_cpath_top
        g.find_const :Apricot
        g.find_const :Identifier
        g.push_literal name
        g.send :intern, 1
      end

      def node_equal?(other)
        self.name == other.name
      end
    end
  end
end
