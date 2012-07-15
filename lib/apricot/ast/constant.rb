module Apricot
  module AST
    class Constant < Node
      attr_reader :names

      def initialize(line, names)
        super(line)
        @names = names
      end

      def bytecode(g)
        pos(g)

        g.push_cpath_top
        @names.each {|n| g.find_const n }
      end

      def assign_bytecode(g, value)
        g.push_cpath_top
        @names[0..-2].each {|n| g.find_const n }
        g.push_literal @names.last
        value.bytecode(g)
        g.send :const_set, 2
      end
    end
  end
end
