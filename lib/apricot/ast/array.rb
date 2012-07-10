module Apricot::AST
  class Array < Node
    attr_reader :value

    def initialize(line, value)
      super(line)
      @value = value
    end

    def bytecode(g)
      pos(g)

      @value.each {|x| x.bytecode(g) }
      g.make_array @value.length
    end
  end
end
