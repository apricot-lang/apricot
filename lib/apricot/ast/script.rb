module Apricot
  module AST
    class Script < Node
      attr_reader :body

      def initialize(body)
        @body = body
      end

      def bytecode(g)
        @body.bytecode(g)
        g.pop
        g.push_true
        g.ret
      end
    end
  end
end
