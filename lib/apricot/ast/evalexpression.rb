module Apricot
  module AST
    class EvalExpression < Node
      attr_reader :body

      def initialize(body)
        @body = body
      end

      def bytecode(g)
        @body.bytecode(g)
        g.ret
      end
    end
  end
end
