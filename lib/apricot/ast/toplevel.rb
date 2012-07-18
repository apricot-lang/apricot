module Apricot
  module AST
    class TopLevel < Node
      attr_accessor :file
      attr_reader :elements

      def initialize(elements)
        @elements = elements
        @line = 1
      end

      def bytecode(g)
        pos(g)

        if @elements.empty?
          g.push_nil
        else
          @elements[0..-2].each do |e|
            e.bytecode(g)
            g.pop
          end
          @elements.last.bytecode(g)
        end

        g.ret
      end
    end
  end
end
