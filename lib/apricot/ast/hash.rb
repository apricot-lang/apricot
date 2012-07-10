module Apricot::AST
  class Hash < Node
    attr_reader :elements

    def initialize(line, elements)
      super(line)
      @elements = elements
    end

    def bytecode(g)
      pos(g)

      # Create a new Hash
      g.push_cpath_top
      g.find_const :Hash
      g.push(@elements.length / 2)
      g.send :new_from_literal, 1

      # Add keys and values
      @elements.each_slice(2) do |k, v|
        g.dup # The Hash
        k.bytecode(g)
        v.bytecode(g)
        g.send :[]=, 2
        g.pop # []= leaves v on the stack
      end
    end
  end
end
