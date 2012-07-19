module Apricot
  module AST
    class TopLevel < Node
      include TopLevelScope

      attr_reader :elements, :file

      def initialize(elements, file)
        @elements = elements
        @file = file
        @line = 1
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
    end
  end
end
