module Apricot::AST
  class Identifier < Node
    attr_reader :name

    def initialize(line, name)
      super(line)
      @name = name
    end

    def bytecode(g)
      pos(g)

      g.push_local 0
    end

    def assign_bytecode(g, value)
      value.bytecode(g)
      g.set_local 0

      g.local_count = 1
      g.local_names = [@name]
    end
  end
end
