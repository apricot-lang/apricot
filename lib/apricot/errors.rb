module Apricot
  class SyntaxError < StandardError
    attr_reader :filename, :line, :msg

    def initialize(filename, line, msg, incomplete = false)
      @filename = filename
      @line = line
      @msg = msg
      @incomplete = incomplete
    end

    def incomplete?
      @incomplete
    end

    def to_s
      "#{@filename}:#{@line}: #{@msg}"
    end
  end

  class CompileError < StandardError
    attr_reader :filename, :line, :msg

    def initialize(filename, line, msg)
      @filename = filename
      @line = line
      @msg = msg
    end

    def to_s
      "#{@filename}:#{@line}: #{@msg}"
    end
  end

  def self.compile_error(file, line, msg)
    raise CompileError.new(file, line, msg)
  end
end
