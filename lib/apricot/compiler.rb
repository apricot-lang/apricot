module Apricot
  module Compiler
    module_function

    def generate(node, file = "(none)", line = 1)
      gen = Apricot::Generator.new
      node.bytecode(gen)
      gen.close
      gen.encode
      cc = gen.package(Rubinius::CompiledCode)
      cc.scope = Rubinius::ConstantScope.new(Object)
      cc
    end

    def compile(file)
      ast = Apricot::Parser.parse_file(file)
      generate(ast, file)
    end

    def compile_string(code, file = "(none)", line = 1)
      ast = Apricot::Parser.parse_string(code, file, line)
      generate(ast, file, line)
    end

    def compile_node(node, file = "(none)", line = 1)
      ast = AST::TopLevel.new([node], file, line, false)
      generate(ast, file, line)
    end

    def compile_form(form, file = "(none)", line = 1)
      compile_node(AST::Node.from_value(form, line), file, line)
    end

    def eval(code, file = "(eval)", line = 1)
      Rubinius.run_script(compile_string(code, file, line))
    end

    def eval_form(form, file = "(eval)", line = 1)
      Rubinius.run_script(compile_form(form, file, line))
    end

    def eval_node(node, file = "(eval)", line = 1)
      Rubinius.run_script(compile_node(node, file, line))
    end
  end
end
