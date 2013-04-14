module Apricot
  module AST
    class Identifier < Node
      def initialize(line, name)
        super(line)

        if name.is_a? Apricot::Identifier
          @id = name
        else
          @id = Apricot::Identifier.intern(name)
        end
      end

      def reference(g)
        @reference ||=
          if name == :self
            SelfReference.new
          elsif qualified?
            NamespaceReference.new(unqualified_name, ns)
          else
            g.scope.find_var(name)
          end
      end

      def name
        @id.name
      end

      def constant?
        @id.constant?
      end

      def qualified?
        @id.qualified?
      end

      def ns
        @id.ns
      end

      def unqualified_name
        @id.unqualified_name
      end

      def const_names
        @id.const_names
      end

      def bytecode(g)
        pos(g)

        if constant?
          g.push_const const_names.first
          const_names.drop(1).each {|n| g.find_const n }
        else
          reference(g).bytecode(g)
        end
      end

      # called by (def <identifier> <value>)
      def assign_bytecode(g, value)
        if constant?
          if const_names.length == 1
            g.push_scope
          else
            g.push_const const_names[0]
            const_names[1..-2].each {|n| g.find_const n }
          end

          g.push_literal const_names.last
          value.bytecode(g)
          g.send :const_set, 2
        else
          g.compile_error "Can't change the value of self" if name == :self

          g.push_const :Apricot
          g.send :current_namespace, 0
          g.push_literal name
          value.bytecode(g)
          g.send :set_var, 2
        end
      end

      def quote_bytecode(g)
        pos(g)

        g.push_const :Apricot
        g.find_const :Identifier
        g.push_literal name
        g.send :intern, 1
      end

      def meta(g)
        ref = reference(g)
        ref.is_a?(NamespaceReference) && ref.meta
      end

      def namespace_fn?(g)
        ref = reference(g)
        ref.is_a?(NamespaceReference) && ref.fn?
      end

      def module_method?(g)
        ref = reference(g)
        ref.is_a?(NamespaceReference) && ref.method?
      end

      def to_value
        @id
      end

      def node_equal?(other)
        self.name == other.name
      end
    end
  end
end
