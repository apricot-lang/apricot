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

    def new_eval(form, file = "(eval)", line = 1)
      Rubinius.run_script(new_generate([form], file, line))
    end

    def new_generate(forms, file = "(none)", line = 1, evaluate = false)
      g = Apricot::Generator.new
      g.name = :__top_level__
      g.file = file.to_sym

      g.scopes << AST::TopLevelScope.new

      g.set_line(line)

      if forms.empty?
        g.push_nil
      else
        forms.each_with_index do |e, i|
          g.pop unless i == 0
          bytecode(g, e)

          # We evaluate top level forms as we generate the bytecode for them
          # so macros can be used immediately after their definitions.
          eval_form(e, file) if evaluate
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

    def bytecode(g, form)
      pos(g, form)

      case form
      when Identifier
        raise NotImplementedError, "identifier bytecode"

      when Seq
        raise NotImplementedError, "seq bytecode"

      when Symbol
        raise NotImplementedError, "symbol bytecode"

      when Array
        raise NotImplementedError, "array bytecode"

      when String
        g.push_literal form
        g.string_dup # Duplicate string to prevent mutating the literal

      when Hash
        raise NotImplementedError, "hash bytecode"

      when Fixnum
        g.push form

      when true
        g.push :true

      when nil
        g.push :nil

      when false
        g.push :false

      when Float
        g.push_unique_literal form

      when Regexp
        raise NotImplementedError, "regexp bytecode"

      when Rational
        # A rational literal should only be converted to a Rational the first
        # time it is encountered. We push a literal nil here, and then
        # overwrite the literal value with the created Rational if it is nil,
        # i.e. the first time only. Subsequent encounters will use the
        # previously created Rational. This idea was copied from
        # Rubinius::AST::RegexLiteral.
        idx = g.add_literal(nil)
        g.push_literal_at idx
        g.dup
        g.is_nil

        lbl = g.new_label
        g.gif lbl
        g.pop
        g.push_self
        g.push form.numerator
        g.push form.denominator
        g.send :Rational, 2, true
        g.set_literal idx
        lbl.set!

      when Set
        raise NotImplementedError, "set bytecode"

      when Bignum
        g.push_unique_literal form

      else
        g.compile_error "Can't generate bytecode for #{form} (#{form.class})"
      end
    end

    def pos(g, form)
      if (meta = form.apricot_meta) && (line = meta[:line])
        g.set_line(line)
      end
    end
  end
end
