module Apricot
  class Compiler < Rubinius::Compiler
    def self.compile(file, output_file = nil)
      output_file ||= Rubinius::Compiler.compiled_name(file)

      compiler = new :apricot_file, :compiled_file
      compiler.parser.input file
      compiler.writer.name = output_file
      prepare_compiled_code(compiler.run)
    end

    def self.compile_string(code, file = "(none)", line = 1)
      compiler = new :apricot_string, :compiled_method
      compiler.parser.input(code, file, line)
      prepare_compiled_code(compiler.run)
    end

    def self.compile_node(node, file = "(none)", line = 1)
      compiler = new :apricot_bytecode, :compiled_method
      compiler.generator.input AST::TopLevel.new([node], file, line, false)
      prepare_compiled_code(compiler.run)
    end

    def self.compile_form(form, file = "(none)", line = 1)
      compile_node(AST::Node.from_value(form, line), file, line)
    end

    def self.prepare_compiled_code(cc)
      cc.scope = Rubinius::ConstantScope.new(Object)
      cc
    end

    def self.eval(code, file = "(eval)", line = 1)
      Rubinius.run_script(compile_string(code, file, line))
    end

    def self.eval_form(form, file = "(eval)", line = 1)
      Rubinius.run_script(compile_form(form, file, line))
    end

    def self.eval_node(node, file = "(eval)", line = 1)
      Rubinius.run_script(compile_node(node, file, line))
    end
  end
end
