module Apricot
  class Generator < Rubinius::Generator
    # We don't use the @state array for anything else, so we're free to use it
    # for scopes.
    def push_scope(scope)
      @state << scope
    end

    alias_method :pop_scope, :pop_state
    alias_method :scope, :state
  end
end
