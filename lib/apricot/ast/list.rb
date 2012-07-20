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
        callee = @elements.shift
        args = @elements

        if callee.is_a?(Identifier) && special = Apricot::SpecialForm[callee.name]
          special.bytecode(g, args)
        else
          callee.bytecode(g)
          args.each {|arg| arg.bytecode(g) }
          g.send :call, args.length
        end
      end
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
