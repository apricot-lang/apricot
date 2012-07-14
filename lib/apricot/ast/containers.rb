module Apricot
  module AST
    class Container < Node
      attr_accessor :file

      def initialize(body)
        @body = body
      end
    end

    class Script < Container
      def bytecode(g)
        @body.bytecode(g)
        g.pop
        g.push_true
        g.ret
      end
    end

    class EvalExpression < Container
      def bytecode(g)
        @body.bytecode(g)
        g.ret
      end
    end
  end
end
