module Apricot::AST
  class SimpleLiteral < Node
    def quote_bytecode(g)
      bytecode(g)
    end
  end

  class Literal < SimpleLiteral
    attr_reader :value

    def initialize(line, value)
      super(line)
      @value = value
    end
  end

  class IntegerLiteral
    def self.new(line, value)
      case value
      when Bignum
        BignumLiteral.new(line, value)
      when Fixnum
        FixnumLiteral.new(line, value)
      else
        raise "#{value} is not an integer"
      end
    end
  end

  class BignumLiteral < Literal
    def bytecode(g)
      pos(g)
      g.push_unique_literal @value
    end
  end

  class FixnumLiteral < Literal
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

  class TrueLiteral < SimpleLiteral
    def bytecode(g)
      pos(g)
      g.push_true
    end
  end

  class FalseLiteral < SimpleLiteral
    def bytecode(g)
      pos(g)
      g.push_false
    end
  end

  class NilLiteral < SimpleLiteral
    def bytecode(g)
      pos(g)
      g.push_nil
    end
  end

  class RationalLiteral < SimpleLiteral
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

  class RegexLiteral < Literal
    def bytecode(g)
      pos(g)

      idx = g.add_literal(nil)
      g.push_literal_at idx
      g.dup
      g.is_nil

      lbl = g.new_label
      g.gif lbl
      g.pop
      g.push_cpath_top
      g.find_const :Regexp
      g.push_literal @value
      g.send :new, 1
      g.set_literal idx
      lbl.set!
    end
  end

  class CollectionLiteral < Node
    attr_reader :elements

    def initialize(line, elements)
      super(line)
      @elements = elements
    end

    def quote_bytecode(g)
      bytecode(g, true)
    end
  end

  class ArrayLiteral < CollectionLiteral
    def bytecode(g, quoted = false)
      pos(g)

      @elements.each {|e| quoted ? e.quote_bytecode(g) : e.bytecode(g) }
      g.make_array @elements.length
    end
  end

  class HashLiteral < CollectionLiteral
    def bytecode(g, quoted = false)
      pos(g)

      # Create a new Hash
      g.push_cpath_top
      g.find_const :Hash
      g.push(@elements.length / 2)
      g.send :new_from_literal, 1

      # Add keys and values
      @elements.each_slice(2) do |k, v|
        g.dup # The Hash

        if quoted
          k.quote_bytecode(g)
          v.quote_bytecode(g)
        else
          k.bytecode(g)
          v.bytecode(g)
        end

        g.send :[]=, 2
        g.pop # []= leaves v on the stack
      end
    end
  end

  class SetLiteral < CollectionLiteral
    def bytecode(g, quoted = false)
      pos(g)

      g.push_cpath_top
      g.find_const :Set
      g.send :new, 0 # TODO: Inline this new?

      @elements.each do |e|
        quoted ? e.quote_bytecode(g) : e.bytecode(g)
        g.send :add, 1
      end
    end
  end
end
