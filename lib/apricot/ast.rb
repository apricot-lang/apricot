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

      def self.from_value(val)
        case val
        when true     then Literal.new(0, :true)
        when false    then Literal.new(0, :false)
        when nil      then Literal.new(0, :nil)
        when Integer  then AST.new_integer(0, val)
        when Symbol   then SymbolLiteral.new(0, val)
        when Float    then FloatLiteral.new(0, val)
        when String   then StringLiteral.new(0, val)
        when Rational then RationalLiteral.new(0, val.numerator, val.denominator)
        when Regexp   then RegexLiteral.new(0, val.source, val.options)
        when Array    then ArrayLiteral.new(0, val.map {|x| from_value x})
        when Set      then SetLiteral.new(0, val.map {|x| from_value x})
        when Apricot::Constant   then Constant.new(0, val.names)
        when Apricot::Identifier then Identifier.new(0, val.name)
        when Apricot::List       then List.new(0, val.map {|x| from_value x})
        when Hash
          elems = []
          val.each_pair {|k,v| elems << from_value(k) << from_value(v) }
          HashLiteral.new(0, elems)
        else
          raise TypeError, "No AST node for #{val} (#{val.class})"
        end
      end
    end
  end
end

%w[literals identifier constant list scopes variables toplevel].each do |r|
  require "apricot/ast/#{r}"
end
