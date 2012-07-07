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

    class SimpleNode < Node
      attr_reader :value

      def initialize(line, value)
        super(line)
        @value = value
      end
    end

    class List < SimpleNode
    end

    class Array < SimpleNode
    end

    class Hash < SimpleNode
    end

    class Identifier < SimpleNode
    end

    class Symbol < SimpleNode
    end

    class Integer < SimpleNode
    end

    class Float < SimpleNode
    end

    class Rational < Node
      attr_reader :numerator, :denominator

      def initialize(line, numerator, denominator)
        super(line)
        @numerator = numerator
        @denominator = denominator
      end
    end
  end
end
