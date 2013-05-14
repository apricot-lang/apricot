module Apricot
  class Generator < Rubinius::Generator
    attr_reader :scopes
    attr_accessor :tail_position

    alias_method :tail_position?, :tail_position

    def initialize
      super
      @scopes = []
      @tail_position = false
    end

    def scope
      @scopes.last
    end

    def compile_error(msg)
      raise CompileError.new(file, line, msg)
    end
  end
end
