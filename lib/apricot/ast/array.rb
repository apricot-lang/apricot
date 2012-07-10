module Apricot::AST
  class Array < Node
    attr_reader :elements

    def initialize(line, elements)
      super(line)
      @elements = elements
    end

    def bytecode(g)
      pos(g)

      @elements.each {|e| e.bytecode(g) }
      g.make_array @elements.length
    end
  end
end
