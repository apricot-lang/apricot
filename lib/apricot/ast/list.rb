module Apricot::AST
  class List < Node
    attr_reader :elements

    def initialize(line, elements)
      super(line)
      @elements = elements
    end

    def bytecode(g)
      pos(g)

      if @elements.empty?
        g.push_literal self
#      else
#        op = @elements.first
#        args = @elements[1..-1]
#
#        if op.is_a?(Identifier) && special = Apricot::SpecialForm[op.name]
#          op.bytecode(g, args)
#        else
#          # TODO
#        end
      end

      # Old hack
#      g.push_self
#      @elements[1..-1].each do |arg|
#        arg.bytecode(g)
#      end
#      g.send @elements[0].name.to_sym, @elements.count - 1, true
    end
  end
end
