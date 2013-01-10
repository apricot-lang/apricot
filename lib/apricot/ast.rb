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
        case val
        when true     then Literal.new(line, :true)
        when false    then Literal.new(line, :false)
        when nil      then Literal.new(line, :nil)
        when Integer  then AST.new_integer(line, val)
        when Symbol   then SymbolLiteral.new(line, val)
        when Float    then FloatLiteral.new(line, val)
        when String   then StringLiteral.new(line, val)
        when Rational then RationalLiteral.new(line, val.numerator, val.denominator)
        when Regexp   then RegexLiteral.new(line, val.source, val.options)
        when Array    then ArrayLiteral.new(line, val.map {|x| from_value x, line})
        when Set      then SetLiteral.new(line, val.map {|x| from_value x, line})
        when Apricot::Identifier then Identifier.new(line, val.name)
        when Apricot::List       then List.new(line, val.map {|x| from_value x, line})
        when Hash
          elems = []
          val.each_pair {|k,v| elems << from_value(k, line) << from_value(v, line) }
          HashLiteral.new(line, elems)
        else
          raise TypeError, "No AST node for #{val} (#{val.class})"
        end
      end
    end
  end
end

%w[literals identifier list scopes variables toplevel].each do |r|
  require "apricot/ast/#{r}"
end
