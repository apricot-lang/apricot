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

    SELF = Identifier.intern(:self)

    def bytecode(g, form, quoted = false)
      pos(g, form)

      case form
      when Identifier
        if quoted
          g.push_const :Apricot
          g.find_const :Identifier
          g.push_literal form.name
          g.send :intern, 1
        else
          if form.constant?
            g.push_const form.const_names.first
            form.const_names.drop(1).each {|n| g.find_const n }
          elsif form == SELF
            g.push_self
          else
            # TODO: Stop using AST stuff.
            AST::NamespaceReference.new(form.unqualified_name, form.ns).bytecode(g)
          end
        end

      when Seq
        raise NotImplementedError, "seq bytecode"

      when Symbol
        g.push_literal form

      when Array
        form.each {|e| bytecode(g, e, quoted) }
        g.make_array form.size

      when String
        g.push_literal form
        g.string_dup # Duplicate string to prevent mutating the literal

      when Hash
        # Create a new Hash
        g.push_const :Hash
        g.push form.size
        g.send :new_from_literal, 1

        # Add keys and values
        form.each_pair do |key, value|
          g.dup # the Hash
          bytecode(g, key, quoted)
          bytecode(g, value, quoted)
          g.send :[]=, 2
          g.pop # drop the return value of []=
        end

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
        once(g) do
          g.push_const :Regexp
          g.push_literal form.source
          g.push form.options
          g.send :new, 2
        end

      when Rational
        # Same idea as used above for Regexp.
        once(g) do
          g.push_self
          g.push form.numerator
          g.push form.denominator
          g.send :Rational, 2, true
        end

      when Set
        g.push_const :Set
        g.send :new, 0 # TODO: Inline this new?

        form.each do |elem|
          bytecode(g, elem, quoted)
          g.send :add, 1
        end

      when Bignum
        g.push_unique_literal form

      else
        g.compile_error "Can't generate bytecode for #{form} (#{form.class})"
      end
    end

    # Some literals, such as regexps and rationals, should only be created the
    # first time they are encountered. We push a literal nil here, and then
    # overwrite the literal value with the created object if it is nil, i.e.
    # the first time only. Subsequent encounters will use the previously
    # created object. This idea was copied from Rubinius::AST::RegexLiteral.
    #
    # The passed block should take a generator and generate the bytecode to
    # create the object the first time.
    def once(g)
      idx = g.add_literal(nil)
      g.push_literal_at idx
      g.dup
      g.is_nil

      lbl = g.new_label
      g.gif lbl
      g.pop

      yield g

      g.set_literal idx
      lbl.set!
    end

    def pos(g, form)
      if (meta = form.apricot_meta) && (line = meta[:line])
        g.set_line(line)
      end
    end
  end
end
