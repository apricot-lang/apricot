module Apricot::AST
  class Literal < Node
    attr_reader :value

    def initialize(line, value)
      super(line)
      @value = value
    end

    def bytecode(g)
      pos(g)
      g.push_literal(@value)
    end
  end

  class StringLiteral < Literal
    def bytecode(g)
      super(g)
      g.string_dup # Duplicate string to avoid mutating the literal
    end
  end

  class RationalLiteral < Node
    attr_reader :numerator, :denominator

    def initialize(line, numerator, denominator)
      super(line)
      @numerator = numerator
      @denominator = denominator
    end

    def bytecode(g)
      pos(g)

      g.push_self
      g.push @numerator
      g.push @denominator
      g.send :Rational, 2, true
    end
  end
end
