module Apricot::AST
  class Identifier < Node
    attr_reader :name

    def initialize(line, name)
      super(line)
      @name = name
    end

    def bytecode(g)
      pos(g)

      g.state.scope.find_var(name).reference.get_bytecode(g)
    end

    def assign_bytecode(g, value)
      # called by (def <self> <value>)
      # TODO: this should assign a variable on the current namespace
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
