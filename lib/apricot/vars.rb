module Apricot
  class Compiler
    class LocalReference
      def initialize(slot, depth = 0)
        @slot = slot
        @depth = depth
      end

      def with_depth(depth)
        self.class.new(@slot, depth)
      end

      def get_bytecode(g)
        if @depth == 0
          g.push_local @slot
        else
          g.push_local_depth @depth, @slot
        end
      end

      def set_bytecode(g)
        if @depth == 0
          g.set_local @slot
        else
          g.set_local_depth @depth, @slot
        end
      end
    end

    class NamespaceReference
      def initialize(name)
        @name = name
      end

      def get_bytecode(g)
        g.push_cpath_top
        g.find_const :Apricot
        g.send :current_namespace, 0
        g.push_literal @name
        g.send :get_var, 1
      end

      def set_bytecode(g)
        g.push_cpath_top
        g.find_const :Apricot
        g.send :current_namespace, 0
        g.swap
        g.push_literal @name
        g.swap
        g.send :set_var, 2
      end
    end

  end
end
