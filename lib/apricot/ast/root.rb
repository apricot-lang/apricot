module Apricot::AST
  class Root < Node
    attr_reader :elements

    def initialize(elements)
      @line = 1
      @elements = elements
    end

    def bytecode(g)
      pos(g)

      @elements << NilLiteral.new(1) if @elements.empty?

      @elements[0..-2].each do |e|
        e.bytecode(g)
        g.pop
      end
      @elements.last.bytecode(g)
    end
  end
end
