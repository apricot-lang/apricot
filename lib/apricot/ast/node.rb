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

      def self.from_value(val, line = 0)
        # Note: This is a very heavily used method. The order of the 'when'
        # clauses below has been determined by measuring which kinds of values
        # are passed most often (more common ones should be checked first).

        case val
        when Apricot::Identifier
          Identifier.new(line, val.name)

        when Apricot::Seq
          List.new(line, val.map {|x| from_value(x, line) })

        when Symbol
          SymbolLiteral.new(line, val)

        when Array
          ArrayLiteral.new(line, val.map {|x| from_value(x, line) })

        when String
          StringLiteral.new(line, val)

        when Hash
          elems = []

          val.each_pair do |k, v|
            elems << from_value(k, line) << from_value(v, line)
          end

          HashLiteral.new(line, elems)

        when Integer
          AST.new_integer(line, val)

        when true
          Literal.new(line, :true)

        when nil
          Literal.new(line, :nil)

        when false
          Literal.new(line, :false)

        when Float
          FloatLiteral.new(line, val)

        when Regexp
          RegexLiteral.new(line, val.source, val.options)

        when Rational
          RationalLiteral.new(line, val.numerator, val.denominator)

        when Set
          SetLiteral.new(line, val.map {|x| from_value(x, line) })

        else
          raise TypeError, "No AST node for #{val} (#{val.class})"
        end
      end
    end
  end
end
