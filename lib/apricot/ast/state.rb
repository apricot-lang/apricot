module Apricot
  module AST
    class State
      attr_accessor :scope

      def initialize(scope)
        @scope = scope
      end
    end
  end
end
