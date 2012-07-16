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

    def quote_bytecode(g)
      pos(g)

      g.push_cpath_top
      g.find_const :Apricot
      g.find_const :Identifier
      g.push_literal @name
      g.send :new, 1
    end
  end
end
