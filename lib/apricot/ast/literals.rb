module Apricot::AST
  class Literal < Node
    attr_reader :value

    def initialize(line, value)
      super(line)
      @value = value
    end
  end

  class IntegerLiteral < Literal
    def bytecode(g)
      pos(g)
      g.push @value
    end
  end

  class FloatLiteral < Literal
    def bytecode(g)
      pos(g)
      g.push_unique_literal @value
    end
  end

  class SymbolLiteral < Literal
    def bytecode(g)
      pos(g)
      g.push_literal @value
    end
  end

  class StringLiteral < Literal
    def bytecode(g)
      pos(g)
      g.push_literal @value
      g.string_dup # Duplicate string to avoid mutating the literal
    end
  end

  class TrueLiteral < Node
    def bytecode(g)
      pos(g)
      g.push_true
    end
  end

  class FalseLiteral < Node
    def bytecode(g)
      pos(g)
      g.push_false
    end
  end

  class NilLiteral < Node
    def bytecode(g)
      pos(g)
      g.push_nil
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

      # A rational literal should only be converted to a Rational the first
      # time it is encountered. We push a literal nil here, and then overwrite
      # the literal value with the created Rational if it is nil, i.e. the
      # first time only. Subsequent encounters will use the previously created
      # Rational. This idea was copied from Rubinius::AST::RegexLiteral.
      idx = g.add_literal(nil)
      g.push_literal_at idx
      g.dup
      g.is_nil

      lbl = g.new_label
      g.gif lbl
      g.pop
      g.push_self
      g.push @numerator
      g.push @denominator
      g.send :Rational, 2, true
      g.set_literal idx
      lbl.set!
    end
  end
end
