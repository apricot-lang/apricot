module Apricot
  class Generator < Rubinius::Generator
    def push_state(scope)
      scope.parent = state.scope if state
      @state << Apricot::AST::State.new(scope)
    end
  end
end
