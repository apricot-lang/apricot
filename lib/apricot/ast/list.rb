module Apricot::AST
  class List < Node
    attr_reader :elements

    def initialize(line, elements)
      super(line)
      @elements = elements
    end

    def bytecode(g, macroexpand = true)
      pos(g)

      if @elements.empty?
        quote_bytecode(g)
        return
      end

      callee = @elements.first
      args = @elements.drop(1)

      # Handle special forms such as def, let, fn, quote, etc
      if callee.is_a?(Identifier) && special = Apricot::SpecialForm[callee.name]
        special.bytecode(g, args)
        return
      end

      if macroexpand
        form = Node.from_value(Apricot.macroexpand(self.to_value), line)

        # Avoid recursing and macroexpanding again if expansion returns a list
        if form.is_a?(List)
          form.bytecode(g, false)
        else
          form.bytecode(g)
        end
        return
      end

      # Handle (foo ...) and (Foo/bar ...) calls
      if callee.is_a?(Identifier)
        meta = callee.meta(g)

        # Handle inlinable function calls
        if meta && meta[:inline] && (!meta[:'inline-arities'] ||
                                     meta[:'inline-arities'].apricot_call(args.length))
          # Apply the inliner macro to the arguments and compile the result.
          inliner = meta[:inline]
          form = Node.from_value(inliner.apricot_call(*args.map(&:to_value)), line)
          form.bytecode(g)
          return
        elsif callee.namespace_fn?(g) || callee.module_method?(g)
          ns_id = Apricot::Identifier.intern(callee.ns.name)
          g.push_const ns_id.const_names.first
          ns_id.const_names.drop(1).each {|n| g.find_const(n) }

          args.each {|arg| arg.bytecode(g) }
          g.send callee.unqualified_name, args.length
          return
        end
      end

      # Handle everything else
      callee.bytecode(g)
      args.each {|arg| arg.bytecode(g) }
      g.send :apricot_call, args.length
    end

    def quote_bytecode(g)
      g.push_const :Apricot
      g.find_const :List

      if @elements.empty?
        g.find_const :EmptyList
      else
        @elements.each {|e| e.quote_bytecode(g) }
        g.send :[], @elements.length
      end
    end

    def to_value
      Apricot::List[*@elements.map(&:to_value)]
    end

    def node_equal?(other)
      self.elements == other.elements
    end

    def [](*i)
      @elements[*i]
    end
  end
end
