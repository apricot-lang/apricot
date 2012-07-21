module Apricot
  class Compiler < Rubinius::Compiler
    def self.compile(file, output = nil, debug = false)
      compiler = new :apricot_file, :compiled_file

      compiler.parser.input file
      compiler.packager.print(BytecodePrinter) if debug
      compiler.writer.name = output || Rubinius::Compiler.compiled_name(file)

      compiler.run
    end

    def self.compile_string(code, file = nil, debug = false)
      compiler = new :apricot_string, :compiled_method

      compiler.parser.input(code, file || "(none)")
      compiler.packager.print(BytecodePrinter) if debug

      compiler.run
    end

	def self.eval(code, file = "(none)", debug = false)
	  cm = compile_string(code, file, debug)
	  cm.scope = Rubinius::ConstantScope.new(Object, nil)
	  Rubinius.run_script cm
	end
  end
end
