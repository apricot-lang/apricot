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
        quote_bytecode(g)
      else
        op = @elements.first
        args = @elements[1..-1]

        if op.is_a?(Identifier) && special = Apricot::SpecialForm[op.name]
          special.bytecode(g, args)
        else
          g.push_nil
          # TODO
        end
      end

      # Old hack
#      g.push_self
#      @elements[1..-1].each do |arg|
#        arg.bytecode(g)
#      end
#      g.send @elements[0].name.to_sym, @elements.count - 1, true
    end

    def quote_bytecode(g)
      g.push_cpath_top
      g.find_const :Apricot
      g.find_const :List

      if @elements.empty?
        g.find_const :EmptyList
      else
        @elements.each {|e| e.quote_bytecode(g) }
        g.send :[], @elements.length
      end
    end
  end
end
