module Apricot
  class Generator < Rubinius::Generator
    def scopes
      @scopes ||= []
    end

    def scope
      @scopes.last
    end

    def compile_error(msg)
      raise CompileError.new(file, line, msg)
    end
  end
end
