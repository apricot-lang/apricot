module Apricot
  class Generator < Rubinius::Generator
    def push_state(scope)
      @state << Apricot::AST::State.new(scope)
    end
  end
end
