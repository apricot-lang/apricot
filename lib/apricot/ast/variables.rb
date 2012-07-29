module Apricot
  module AST
    class LocalReference
      def initialize(slot, depth = 0)
        @slot = slot
        @depth = depth
      end

      def bytecode(g)
        if @depth == 0
          g.push_local @slot
        else
          g.push_local_depth @depth, @slot
        end
      end
    end

    class NamespaceReference
      def initialize(name)
        @name = name
      end

      def bytecode(g)
        g.push_cpath_top
        g.find_const :Apricot
        g.send :current_namespace, 0
        g.push_literal @name
        g.send :get_var, 1
      end
    end
  end
end
