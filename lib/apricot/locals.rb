module Apricot
  class Compiler
    class LocalVariable
      attr_reader :slot

      def initialize(slot)
        @slot = slot
      end

      def reference
        LocalReference.new @slot
      end
    end

    class LocalReference
      attr_accessor :depth
      attr_reader :slot

      def initialize(slot, depth = 0)
        @slot = slot
        @depth = depth
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
  end
end
