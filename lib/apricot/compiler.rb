module Apricot
  module Compiler
    module_function

    def generate(forms, file = "(none)", line = 1, evaluate = false)
      g = Generator.new
      g.name = :__apricot__
      g.file = file.to_sym

      g.scopes << TopLevelScope.new

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

    def compile_and_eval_file(file)
      cc = generate(Reader.read_file(file), file, 1, true)

      if Rubinius::CodeLoader.save_compiled?
        compiled_name = Rubinius::Compiler.compiled_name(file)

        dir = File.dirname(compiled_name)

        unless File.directory?(dir)
          parts = []

          until dir == "/" or dir == "."
            parts << dir
            dir = File.dirname(dir)
          end

          parts.reverse_each do |d|
            Dir.mkdir d unless File.directory?(d)
          end
        end

        Rubinius::CompiledFile.dump cc, compiled_name,
          Rubinius::Signature, Rubinius::RUBY_LIB_VERSION
      end

      cc
    end

    def compile_form(form, file = "(eval)", line = 1)
      generate([form], file, line)
    end

    def eval_form(form, file = "(eval)", line = 1)
      Rubinius.run_script(compile_form(form, file, line))
    end

    def eval(code, file = "(eval)", line = 1)
      forms = Reader.read_string(code, file,line)

      forms[0..-2].each do |node|
        new_eval(node, file, line)
      end

      # Return the result of the last form in the program.
      eval_form(forms.last, file, line)
    end

    SELF = Identifier.intern(:self)

    def bytecode(g, form, quoted = false, macroexpand = true)
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
          elsif form.qualified?
            QualifiedReference.new(form.unqualified_name, form.qualifier).bytecode(g)
          else
            g.scope.find_var(form.name).bytecode(g)
          end
        end

      when Seq
        if quoted || form.empty?
          g.push_const :Apricot
          g.find_const :List

          if form.empty?
            g.find_const :EMPTY_LIST
          else
            form.each {|e| bytecode(g, e, true) }
            g.send :[], form.count
          end
        else
          callee, args = form.first, form.rest

          # Handle special forms such as def, let, fn, quote, etc
          if callee.is_a?(Identifier)
            if special = SpecialForm[callee.name]
              special.bytecode(g, args)
              return
            end

            if macroexpand
              form = Apricot.macroexpand(form)

              if form.is_a?(Seq)
                # Avoid recursing and macroexpanding again if expansion returns a list
                bytecode(g, form, false, false)
              else
                bytecode(g, form)
              end

              return
            end

            meta = callee.meta

            # Handle inlinable function calls
            if meta && meta[:inline] && (!meta[:'inline-arities'] ||
                                         meta[:'inline-arities'].apricot_call(args.count))
              begin
                inlined_form = meta[:inline].apricot_call(*args)
              rescue => e
                g.compile_error "Inliner function for '#{callee.name}' raised an exception:\n  #{e}"
              end

              bytecode(g, inlined_form)
              return
            end

            if callee.fn? || callee.method?
              qualifier_id = Identifier.intern(callee.qualifier.name)
              first_name, *rest_names = qualifier_id.const_names

              g.push_const first_name
              rest_names.each {|n| g.find_const(n) }

              args.each {|arg| bytecode(g, arg) }
              g.send callee.unqualified_name, args.count
              return
            end
          end

          # Handle everything else
          bytecode(g, callee)
          args.each {|arg| bytecode(g, arg) }
          g.send :apricot_call, args.count
        end

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
