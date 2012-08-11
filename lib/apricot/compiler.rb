module Apricot
  class Compiler < Rubinius::Compiler
    def self.compile(file, output = nil, debug = false)
      compiler = new :apricot_file, :compiled_file

      compiler.parser.input file
      compiler.packager.print(BytecodePrinter) if debug
      compiler.writer.name = output || Rubinius::Compiler.compiled_name(file)

      compiler.run
    end

    def self.compile_string(code, file = nil, line = 1, debug = false)
      compiler = new :apricot_string, :compiled_method

      compiler.parser.input(code, file || "(none)", line)
      compiler.packager.print(BytecodePrinter) if debug

      compiler.run
    end

    def self.compile_node(node, file = "(none)", line = 1, debug = false)
      compiler = new :apricot_bytecode, :compiled_method

      compiler.generator.input AST::TopLevel.new([node], file, line, false)
      compiler.packager.print(BytecodePrinter) if debug

      compiler.run
    end

    def self.eval(code, file = "(none)", line = 1, debug = false)
      if code.is_a? AST::Node
        cm = compile_node(code, file, line, debug)
      else
        cm = compile_string(code, file, line, debug)
      end

      cm.scope = Rubinius::ConstantScope.new(Object)
      Rubinius.run_script cm
    end
  end
end
