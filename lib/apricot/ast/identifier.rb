module Apricot::AST
  class Identifier < Node
    attr_reader :name

    def initialize(line, name)
      super(line)
      @name = name
    end

    def bytecode(g)
      pos(g)

      # TODO
    end
  end
end
