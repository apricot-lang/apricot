module Apricot
  class SpecialForm
    class ArgList
      attr_reader :required_args, :optional_args, :rest_arg, :block_arg,
        :num_required, :num_optional, :num_total

      def initialize(args, g)
        state = :required

        @required_args = []
        @optional_args = []
        @rest_arg = nil
        @block_arg = nil

        args.each do |arg|
          # Check if we got one of the special identifiers which moves us to a
          # different part of the argument list. If so, move to the new state
          # and skip to the next argument. Also check that the current state
          # is allowed to move to the new state (the arguments must come in a
          # strict order: required, optional, rest, block).
          if arg.is_a? Identifier
            case arg.name
            # '?' starts the optional arguments section.
            when :'?'
              case state
              when :required
                state = :start_optional
                next
              else
                g.compile_error "Unexpected '?' in argument list"
              end

            # '&' precedes the rest argument.
            when :&
              case state
              when :required, :optional
                state = :rest
                next
              else
                g.compile_error "Unexpected '&' in argument list"
              end

            # '|' precedes the block argument.
            when :|
              case state
              when :required, :optional, :after_rest
                state = :block
                next
              else
                g.compile_error "Unexpected '|' in argument list"
              end
            end
          end

          # Deal with the argument based on the current state.
          case state
          when :required
            g.compile_error "Required argument in argument list must be an identifier" unless arg.is_a? Identifier
            @required_args << arg.name

          when :optional, :start_optional
            unless arg.is_a?(Seq) && arg.count == 2 && arg.first.is_a?(Identifier)
              g.compile_error "Optional argument in argument list must be of the form (name default)"
            end

            state = :optional
            @optional_args << [arg.first.name, arg.rest.first]

          when :rest
            g.compile_error "Rest argument in argument list must be an identifier" unless arg.is_a? Identifier
            @rest_arg = arg.name
            state = :after_rest

          when :block
            g.compile_error "Block argument in argument list must be an identifier" unless arg.is_a? Identifier
            @block_arg = arg.name
            state = :after_block

          when :after_rest
            g.compile_error "Unexpected argument after rest argument"

          when :after_block
            g.compile_error "Unexpected arguments after block argument"
          end
        end

        # Check if we finished in the middle of things without getting an
        # argument where we expected one.
        case state
        when :start_optional
          g.compile_error "Expected optional arguments after '?' in argument list"

        when :rest
          g.compile_error "Expected rest argument after '&' in argument list"

        when :block
          g.compile_error "Expected block argument after '|' in argument list"
        end

        @num_required = @required_args.length
        @num_optional = @optional_args.length
        @num_total = @num_required + @num_optional
      end

      def to_array
        args = @required_args.map {|id| Identifier.intern(id) }
        args += @optional_args.map {|name, val| [Identifier.intern(name), val.to_value] }
        args += [Identifier.intern(:|), Identifier.intern(@block_arg)] if @block_arg
        args += [Identifier.intern(:&), Identifier.intern(@rest_arg)] if @rest_arg
        args
      end
    end

    Overload = Struct.new(:arglist, :body)

    # (fn name? [args*] body*)
    # (fn name? [args* | block] body*)
    # (fn name? [args* & rest] body*)
    # (fn name? [args* & rest | block] body*)
    # (fn name? ([args*] body*) ... ([args*] body*))
    SpecialForm.define(:fn) do |g, args|
      fn_name, args = args.first.name, args.rest if args.first.is_a? Identifier
      doc_string, args = args.first, args.rest if args.first.is_a? String

      overloads = []

      case args.first
      when Seq
        # This is the multi-arity form (fn name? ([args*] body*) ... ([args*] body*))
        args.each do |overload|
          # Each overload is of the form ([args*] body*)
          g.compile_error "Expected an arity overload (a list)" unless overload.is_a? Seq
          arglist, body = overload.first, overload.rest
          g.compile_error "Argument list in overload must be an array literal" unless arglist.is_a? Array
          arglist = ArgList.new(arglist, g)
          overloads << Overload.new(arglist, body)
        end
      when Array
        # This is the single-arity form (fn name? [args*] body*)
        arglist, body = args.first, args.rest
        arglist = ArgList.new(arglist, g)
        overloads << Overload.new(arglist, body)
      else
        # Didn't match any of the legal forms.
        g.compile_error "Expected argument list or arity overload in fn definition"
      end

      # Check that the overloads do not conflict with each other.
      if overloads.length > 1
        variadic, normals = overloads.partition {|overload| overload.arglist.rest_arg }

        g.compile_error "Can't have more than one variadic overload" if variadic.length > 1

        # Sort the non-variadic overloads by ascending number of required arguments.
        normals.sort_by! {|overload| overload.arglist.num_required }

        if variadic.length == 1
          # If there is a variadic overload, it should have at least as many
          # required arguments as the next highest overload.
          variadic_arglist = variadic.first.arglist
          if variadic_arglist.num_required < normals.last.arglist.num_required
            g.compile_error "Can't have a fixed arity overload with more params than a variadic overload"
          end

          # Can't have two overloads with same number of required args unless
          # they have no optional args and one of them is the variadic overload.
          if variadic_arglist.num_required == normals.last.arglist.num_required &&
            (variadic_arglist.num_optional != 0 || normals.last.arglist.num_optional != 0)
            g.compile_error "Can't have two overloads with the same arity"
          elsif normals.last.arglist.num_total > variadic_arglist.num_required
            g.compile_error "Can't have an overload with more total (required + optional) arguments than the variadic overload has required argument"
          end
        end

        # Compare each consecutive two non-variadic overloads.
        normals.each_cons(2) do |o1, o2|
          arglist1 = o1.arglist
          arglist2 = o2.arglist
          if arglist1.num_required == arglist2.num_required
            g.compile_error "Can't have two overloads with the same arity"
          elsif arglist1.num_total >= arglist2.num_required
            g.compile_error "Can't have an overload with as many total (required + optional) arguments as another overload has required arguments"
          end
        end

        overloads = normals + variadic
      end

      fn = g.class.new
      fn.name = fn_name || :__fn__
      fn.file = g.file

      fn.definition_line g.line
      fn.set_line g.line

      fn.total_args = 0
      fn.required_args = 0
      fn.local_count = 0
      fn.local_names = []

      fn_scope = FnScope.new(g.scope, fn_name)

      # Generate the code that selects and jumps to the correct overload based
      # on the number of arguments passed.
      if overloads.length > 1
        overload_labels = overloads.map { fn.new_label }
        nomatch_possible = false # Is it possible to match no overload?
        nomatch = fn.new_label

        last_args = overloads.last.arglist
        if last_args.rest_arg
          if overloads[-2].arglist.num_required == last_args.num_required
            fn.passed_arg last_args.num_required
          else
            fn.passed_arg last_args.num_required - 1
          end
          fn.git overload_labels.last
        else
          fn.passed_arg last_args.num_required - 1
          fn.git overload_labels.last
        end

        prev_num_required = last_args.num_required

        (overloads.length - 2).downto(0) do |i|
          arglist = overloads[i].arglist

          jump = prev_num_required - arglist.num_total
          if jump > 1
            nomatch_possible = true
            fn.passed_arg arglist.num_total
            fn.git nomatch
          end

          if arglist.num_required == 0
            if nomatch_possible
              fn.goto overload_labels[i]
            end
          else
            fn.passed_arg arglist.num_required - 1
            fn.git overload_labels[i]
          end

          prev_num_required = arglist.num_required
        end

        if nomatch_possible
          nomatch.set!
          fn.push_const :ArgumentError
          fn.push_literal "No matching overload"
          fn.string_dup
          fn.send :new, 1
          fn.raise_exc
        end
      end

      overloads.each_with_index do |overload, i|
        arglist, body = overload.arglist, overload.body
        overload_scope = OverloadScope.new(fn_scope)
        fn.scopes << overload_scope

        # Check if there are any duplicate names in the argument list.
        argnames = arglist.required_args + arglist.optional_args.map(&:first)
        argnames << arglist.rest_arg if arglist.rest_arg
        argnames << arglist.block_arg if arglist.block_arg
        dup_name = argnames.detect {|name| argnames.count(name) > 1 }
        g.compile_error "Duplicate argument name '#{dup_name}'" if dup_name

        overload_labels[i].set! if overloads.length > 1

        # Allocate slots for the required arguments
        arglist.required_args.each {|arg| overload_scope.new_local(arg) }

        next_optional = fn.new_label

        arglist.optional_args.each_with_index do |(name, value), i|
          # Calculate the position of this optional arg, off the end of the
          # required args
          arg_index = arglist.num_required + i

          # Allocate a slot for this optional argument
          overload_scope.new_local(name)

          fn.passed_arg arg_index
          fn.git next_optional

          Compiler.bytecode(fn, value)
          fn.set_local arg_index
          fn.pop

          next_optional.set!
          next_optional = fn.new_label
        end

        if arglist.rest_arg
          # Allocate the slot for the rest argument
          overload_scope.new_local(arglist.rest_arg)
          overload_scope.splat = true
        end

        overload_scope.loop_label = next_optional
        overload_scope.loop_label.set!

        # Allocate the slot for the block argument
        if arglist.block_arg
          overload_scope.new_local(arglist.block_arg)
          overload_scope.block_arg = arglist.block_arg
          fn.push_proc
          fn.set_local overload_scope.find_var(arglist.block_arg).slot
          fn.pop
        end

        fn.tail_position = true
        SpecialForm[:do].bytecode(fn, body)
        fn.ret

        # TODO: does this make any sense with overloads?
        fn.local_count += overload_scope.local_count
        fn.local_names += overload_scope.local_names

        # Pop the overload scope
        fn.scopes.pop
      end

      fn.close

      # Use the maximum total args
      fn.total_args = overloads.last.arglist.num_total
      # Use the minimum required args
      fn.required_args = overloads.first.arglist.num_required

      # If there is a rest arg, it will appear after all the required and
      # optional arguments.
      fn.splat_index = overloads.last.arglist.num_total if overloads.last.arglist.rest_arg

      g.push_const :Kernel
      g.create_block fn
      g.send_with_block :lambda, 0
      g.set_local fn_scope.self_reference.slot if fn_name
    end
  end
end
