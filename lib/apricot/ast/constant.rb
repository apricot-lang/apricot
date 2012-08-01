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

      def quote_bytecode(g)
        g.push_cpath_top
        g.find_const :Apricot
        g.find_const :Constant
        @names.each {|name| g.push_literal name }
        g.send :new, @names.length
      end

      def to_value
        Apricot::Constant.new(*@names)
      end

      def node_equal?(other)
        self.names == other.names
      end
    end
  end
end
