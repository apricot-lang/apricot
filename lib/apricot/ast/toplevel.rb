module Apricot
  module AST
    class TopLevel < Node
      include StorageScope

      attr_reader :elements, :file

      def initialize(elements, file, line = 1, evaluate = false)
        @elements = elements
        @file = file
        @line = line
        @evaluate = evaluate
      end

      def bytecode(g)
        g.name = :__top_level__
        g.file = @file.to_sym

        g.scopes << self

        pos(g)

        if @elements.empty?
          g.push_nil
        else
          @elements.each_with_index do |e, i|
            g.pop unless i == 0
            e.bytecode(g)
            # We evaluate top level forms as we generate the bytecode for them
            # so macros defined in a file can be used immediately after the
            # definition.
            Apricot::Compiler.eval(e, @file) if @evaluate
          end
        end

        g.ret

        g.scopes.pop

        g.local_count = local_count
        g.local_names = local_names
      end

      # A nested scope is looking up a variable. There are no local variables
      # at the top level, so look up the variable on the current namespace.
      def find_var(name, depth = nil)
        # Ignore depth, it has no bearing on namespace lookups.
        NamespaceReference.new(name)
      end

      def node_equal?(other)
        self.file == other.file && self.elements == other.elements
      end

      def [](*i)
        @elements[*i]
      end

      # A (recur) is looking for a recursion target. Since this is the top
      # level, which has no parent, the lookup has failed.
      def find_recur_target
        nil
      end
    end
  end
end
