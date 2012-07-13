module Apricot
  class Compiler < Rubinius::Compiler
    def self.compile(file, output = nil, debug = false)
      compiler = new :apricot_file, :compiled_file

      compiler.parser.root AST::Script
      compiler.parser.input file
      compiler.packager.print(BytecodePrinter) if debug
      compiler.writer.name = output || Rubinius::Compiler.compiled_name(file)

      compiler.run
    end

    def self.compile_string(code, file = "(eval)", debug = false)
      compiler = new :apricot_string, :compiled_method

      compiler.parser.root AST::EvalExpression
      compiler.parser.input code, file
      compiler.packager.print(BytecodePrinter) if debug

      compiler.run
    end
  end
end
