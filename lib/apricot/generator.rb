module Apricot
  class Generator < Rubinius::Generator
    def scopes
      @scopes ||= []
    end

    def scope
      @scopes.last
    end
  end
end
