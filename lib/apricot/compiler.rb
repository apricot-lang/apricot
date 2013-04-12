module Apricot
  class Compiler < Rubinius::Compiler
    def self.compile(file, output = nil, debug = false)
      compiler = new :apricot_file, :compiled_file

      compiler.parser.input file
      compiler.packager.print(BytecodePrinter) if debug
      compiler.writer.name = output || Rubinius::Compiler.compiled_name(file)

      prepare_compiled_code compiler.run
    end

    def self.compile_string(code, file = nil, line = 1, debug = false)
      compiler = new :apricot_string, :compiled_method

      compiler.parser.input(code, file || "(none)", line)
      compiler.packager.print(BytecodePrinter) if debug

      prepare_compiled_code compiler.run
    end

    def self.compile_node(node, file = "(none)", line = 1, debug = false)
      compiler = new :apricot_bytecode, :compiled_method

      compiler.generator.input AST::TopLevel.new([node], file, line, false)
      compiler.packager.print(BytecodePrinter) if debug

      prepare_compiled_code compiler.run
    end

    def self.compile_form(node, file = "(none)", line = 1, debug = false)
      compile_node(AST::Node.from_value(node, line), file, line, debug)
    end

    def self.prepare_compiled_code(cc)
      cc.scope = Rubinius::ConstantScope.new(Object)
      cc
    end

    def self.eval(code, file = "(eval)", line = 1, debug = false)
      cc = compile_string(code, file, line, debug)
      Rubinius.run_script cc
    end

    def self.eval_form(form, file = "(eval)", line = 1, debug = false)
      cc = compile_form(form, file, line, debug)
      Rubinius.run_script cc
    end

    def self.eval_node(node, file = "(eval)", line = 1, debug = false)
      cc = compile_node(node, file, line, debug)
      Rubinius.run_script cc
    end
  end
end
