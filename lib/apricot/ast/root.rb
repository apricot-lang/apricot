module Apricot::AST
  class Root < Node
    attr_reader :elements

    def initialize(elements)
      @elements = elements
    end

    def bytecode(g)
      last_i = @elements.count - 1
      @elements.each_with_index do |e, i|
        start_ip = g.ip
        e.bytecode(g)
        g.pop unless start_ip == g.ip or i == last_i
      end
    end
  end
end
