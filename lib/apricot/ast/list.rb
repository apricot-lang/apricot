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
      else
        op = @elements.first
        args = @elements[1..-1]

        # Interop expansion
        if op.is_a?(Identifier)
          name = op.name.to_s

          if name.start_with?('.')
            op = Identifier.new(op.line, :'.')
            method = Identifier.new(op.line, name[1..-1].to_sym)
            args.insert(1, method)
          elsif name.end_with?('.')
            op = Identifier.new(op.line, :'.')
            clazz = Identifier.new(op.line, name[0..-2].to_sym)
            method = Identifier.new(op.line, :new)
            args.unshift(clazz, method)
          end
        end

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
  end
end
