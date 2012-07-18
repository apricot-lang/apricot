module Apricot
  module AST
    class TopLevel < Node
      attr_reader :elements, :file

      def initialize(elements, file)
        @elements = elements
        @file = file
        @line = 1
      end

      def bytecode(g)
        g.name = :__top_level__
        g.file = @file.to_sym

#        g.push_state self

        if @elements.empty?
          pos(g)
          g.push_nil
        else
          @elements[0..-2].each do |e|
            e.bytecode(g)
            g.pop
          end
          @elements.last.bytecode(g)
        end

        g.ret

#        g.pop_state

#        g.local_count = local_count
#        g.local_names = local_names
      end
    end
  end
end
