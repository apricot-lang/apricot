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
    end
  end
end

%w{literals identifier list array hash root script evalexpression}.map do |r|
  require "apricot/ast/#{r}"
end
