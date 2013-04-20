module Apricot
  module Compiler
    module_function

    def generate(nodes, file = "(none)", line = 1, evaluate = false)
      g = Apricot::Generator.new
      g.name = :__top_level__
      g.file = file.to_sym

      g.scopes << AST::TopLevelScope.new

      g.set_line(line)

      if nodes.empty?
        g.push_nil
      else
        nodes.each_with_index do |e, i|
          g.pop unless i == 0
          e.bytecode(g)

          # We evaluate top level forms as we generate the bytecode for them
          # so macros can be used immediately after their definitions.
          eval_node(e, file) if evaluate
        end
      end

      g.ret

      scope = g.scopes.pop
      g.local_count = scope.local_count
      g.local_names = scope.local_names

      g.close
      g.encode
      cc = g.package(Rubinius::CompiledCode)
      cc.scope = Rubinius::ConstantScope.new(Object)
      cc
    end

    def compile(file)
      nodes = Apricot::Reader.read_file(file).map {|v| AST::Node.from_value(v, 1) }
      generate(nodes, file, 1, true)
    end

    def eval(code, file = "(eval)", line = 1)
      nodes = Apricot::Reader.read_string(code, file, line).map {|v| AST::Node.from_value(v, line) }
      return nil if nodes.empty?

      nodes[0..-2].each do |node|
        eval_node(node, file, line)
      end

      # Return the result of the last form in the program.
      eval_node(nodes.last, file, line)
    end

    def compile_node(node, file = "(none)", line = 1)
      generate([node], file, line)
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
