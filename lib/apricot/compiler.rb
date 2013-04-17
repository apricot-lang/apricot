module Apricot
  module Compiler
    module_function

    def generate(node)
      gen = Apricot::Generator.new
      node.bytecode(gen)
      gen.close
      gen.encode
      cc = gen.package(Rubinius::CompiledCode)
      cc.scope = Rubinius::ConstantScope.new(Object)
      cc
    end

    def compile(file)
      nodes = Apricot::Parser.parse_file(file)
      ast = AST::TopLevel.new(nodes, file, 1, true)
      generate(ast)
    end

    def eval(code, file = "(eval)", line = 1)
      nodes = Apricot::Parser.parse_string(code, file, line)
      return nil if nodes.empty?

      nodes[0..-2].each do |node|
        eval_node(node, file, line)
      end

      # Return the result of the last form in the program.
      eval_node(nodes.last, file, line)
    end

    def compile_node(node, file = "(none)", line = 1)
      ast = AST::TopLevel.new([node], file, line, false)
      generate(ast)
    end

    def compile_form(form, file = "(none)", line = 1)
      compile_node(AST::Node.from_value(form, line), file, line)
    end

    def eval_node(node, file = "(eval)", line = 1)
      Rubinius.run_script(compile_node(node, file, line))
    end

    def eval_form(form, file = "(eval)", line = 1)
      Rubinius.run_script(compile_form(form, file, line))
    end
  end
end
