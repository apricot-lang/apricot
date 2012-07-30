module Apricot
  module AST
    class Node
      attr_reader :line

      def initialize(line)
        @line = line
      end

      def pos(g)
        g.set_line(@line)
      end

      def ==(other)
        return true if self.equal?(other)
        return false unless self.class == other.class
        self.node_equal?(other)
      end
    end
  end
end

%w[literals identifier constant send list scopes variables toplevel].each do |r|
  require "apricot/ast/#{r}"
end
