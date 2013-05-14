module Apricot
  class Generator < Rubinius::Generator
    attr_reader :scopes

    def initialize
      @scopes = []
      super
    end

    def scope
      @scopes.last
    end

    def compile_error(msg)
      raise CompileError.new(file, line, msg)
    end
  end
end
