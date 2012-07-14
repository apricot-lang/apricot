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

        g.push_const @names.first
        @names[1..-1].each {|n| g.find_const n }
      end
    end
  end
end
