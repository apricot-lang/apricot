module Apricot
  class Compiler
    class Generator < Rubinius::Compiler::Stage
      stage :apricot_bytecode
      next_stage Rubinius::Compiler::Encoder

      def initialize(compiler, last)
        super
        compiler.generator = self
      end

      def run
        @output = Rubinius::Generator.new
        @input.bytecode @output
        @output.close
        run_next
      end
    end

    class Parser < Rubinius::Compiler::Stage
      def initialize(compiler, last)
        super
        compiler.parser = self
      end

	  def root(klass)
		@root = klass
	  end

      def run
        @output = @root.new parse
        run_next
      end
    end

    class FileParser < Parser
      stage :apricot_file
      next_stage Generator

      def parse
        Apricot::Parser.parse_file(@input)
      end
    end

    class StringParser < Parser
      stage :apricot_string
      next_stage Generator

      def input(code, file = "(none)")
        @input = code
        @file = file
      end

      def parse
        Apricot::Parser.parse_string(@input, @file)
      end
    end
  end
end
