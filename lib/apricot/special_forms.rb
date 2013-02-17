module Apricot
  class SpecialForm
    Specials = {}

    def self.[](name)
      Specials[name.to_sym]
    end

    def self.define(name, &block)
      name = name.to_sym
      Specials[name] = new(name, block)
    end

    def initialize(name, block)
      @name = name.to_sym
      @block = block
    end

    def bytecode(g, args)
      @block.call(g, args)
    end
  end

  # (. receiver method args*)
  # (. receiver method args* & rest)
  # (. receiver method args* | block)
  # (. receiver method args* & rest | block)
  # (. receiver (method args*))
  # (. receiver (method args* & rest))
  # (. receiver (method args* | block))
  # (. receiver (method args* & rest | block))
  SpecialForm.define(:'.') do |g, args|
    g.compile_error "Too few arguments to send expression, expecting (. receiver method ...)" if args.length < 2

    receiver, method_or_list = args.shift(2)

    # Handle the (. receiver (method args*)) form
    if method_or_list.is_a? AST::List
      method = method_or_list.elements.shift

      g.compile_error "Invalid send expression, expecting (. receiver (method ...))" unless args.empty?

      args = method_or_list.elements
    else
      method = method_or_list
    end

    g.compile_error "Method in send expression must be an identifier" unless method.is_a? AST::Identifier

    block_arg = nil
    splat_arg = nil

    if args[-2].is_a?(AST::Identifier) && args[-2].name == :|
      block_arg = args.last
      args.pop(2)
    end

    if args[-2].is_a?(AST::Identifier) && args[-2].name == :&
      splat_arg = args.last
      args.pop(2)
    end

    args.each do |arg|
      next unless arg.is_a?(AST::Identifier)
      g.compile_error "Incorrect use of & in send expression" if arg.name == :&
      g.compile_error "Incorrect use of | in send expression" if arg.name == :|
    end

    receiver.bytecode(g)

    if block_arg || splat_arg
      args.each {|a| a.bytecode(g) }

      if splat_arg
        splat_arg.bytecode(g)
        g.cast_array unless splat_arg.is_a?(AST::ArrayLiteral)
      end

      if block_arg
        nil_block = g.new_label
        block_arg.bytecode(g)
        g.dup
        g.is_nil
        g.git nil_block

        g.push_cpath_top
        g.find_const :Proc

        g.swap
        g.send :__from_block__, 1

        nil_block.set!
      else
        g.push_nil
      end

      if splat_arg
        g.send_with_splat method.name, args.length
      else
        g.send_with_block method.name, args.length
      end

    elsif method.name == :new
      slow = g.new_label
      done = g.new_label

      g.dup # dup the receiver
      g.check_serial :new, Rubinius::CompiledMethod::KernelMethodSerial
      g.gif slow

      # fast path
      g.send :allocate, 0, true
      g.dup
      args.each {|a| a.bytecode(g) }
      g.send :initialize, args.length, true
      g.pop

      g.goto done

      # slow path
      slow.set!
      args.each {|a| a.bytecode(g) }
      g.send :new, args.length

      done.set!

    else
      args.each {|a| a.bytecode(g) }
      g.send method.name, args.length
    end
  end

  # (def name value?)
  SpecialForm.define(:def) do |g, args|
    g.compile_error "Too few arguments to def" if args.length < 1
    g.compile_error "Too many arguments to def" if args.length > 2

    target, value = *args

    value ||= AST::Literal.new(0, :nil)

    case target
    when AST::Identifier
      target.assign_bytecode(g, value)
    else
      g.compile_error "First argument to def must be an identifier"
    end
  end

  # (if cond body else_body?)
  SpecialForm.define(:if) do |g, args|
    g.compile_error "Too few arguments to if" if args.length < 2
    g.compile_error "Too many arguments to if" if args.length > 3

    cond, body, else_body = args
    else_label, end_label = g.new_label, g.new_label

    cond.bytecode(g)
    g.gif else_label

    body.bytecode(g)
    g.goto end_label

    else_label.set!
    if else_body
      else_body.bytecode(g)
    else
      g.push_nil
    end

    end_label.set!
  end

  # (do body*)
  SpecialForm.define(:do) do |g, args|
    if args.empty?
      g.push_nil
    else
      args[0..-2].each do |a|
        a.bytecode(g)
        g.pop
      end
      args.last.bytecode(g)
    end
  end

  # (quote form)
  SpecialForm.define(:quote) do |g, args|
    g.compile_error "Too few arguments to quote" if args.length < 1
    g.compile_error "Too many arguments to quote" if args.length > 1

    args.first.quote_bytecode(g)
  end

  # Code shared between let and loop. type is :let or :loop
  def self.let(g, args, type)
    g.compile_error "Too few arguments to #{type}" if args.length < 1
    g.compile_error "First argument to #{type} must be an array literal" unless args.first.is_a? AST::ArrayLiteral

    bindings = args.shift.elements

    g.compile_error "Bindings array for #{type} must contain an even number of forms" if bindings.length.odd?

    scope = AST::LetScope.new(g.scope)
    g.scopes << scope

    bindings.each_slice(2) do |name, value|
      g.compile_error "Binding targets in let must be identifiers" unless name.is_a? AST::Identifier

      value.bytecode(g)
      g.set_local scope.new_local(name)
      g.pop
    end

    if type == :loop
      scope.loop_label = g.new_label
      scope.loop_label.set!
    end

    SpecialForm[:do].bytecode(g, args)

    g.scopes.pop
  end

  # (let [binding*] body*) where binding is an identifier followed by a value
  SpecialForm.define(:let) do |g, args|
    let(g, args, :let)
  end

  # (loop [binding*] body*) where binding is an identifier followed by a value
  # Just like let but also introduces a loop target for (recur ...)
  SpecialForm.define(:loop) do |g, args|
    let(g, args, :loop)
  end

  # (recur args*)
  # Rebinds the arguments of the nearest enclosing loop or fn and jumps to the
  # top of the loop/fn. Argument rebinding is done in parallel (rebinding a
  # variable in a recur will not affect uses of that variable in the other
  # recur bindings.)
  SpecialForm.define(:recur) do |g, args|
    target = g.scope.find_recur_target
    g.compile_error "No recursion target found for recur" unless target
    vars = target.variables.values

    # If there is a block arg, ignore it.
    if target.is_a?(AST::OverloadScope) && target.block_arg
      vars.pop
    end

    g.compile_error "Arity of recur does not match enclosing loop or fn" unless vars.length == args.length

    args.each {|arg| arg.bytecode(g) }

    # If the recur is in a variadic overload scope, and there is another
    # overload with the same number of total arguments (not counting the
    # variadic argument), then we must jump to that other overload if the
    # list passed for the variadic argument list is empty.
    variadic_with_secondary =
      target.is_a?(AST::OverloadScope) &&
      target.splat? &&
      target.secondary_loop_label

    if variadic_with_secondary
      g.dup_top
      g.move_down args.length # Save the variadic list behind the other args.
    end

    vars.reverse_each do |var|
      g.set_local var
      g.pop
    end

    if variadic_with_secondary
      g.send :empty?, 0 # Check if the variadic list is empty.
      g.goto_if_true target.secondary_loop_label
    end

    g.check_interrupts
    g.goto target.loop_label
  end

  class ArgList
    attr_reader :required_args, :optional_args, :rest_arg, :block_arg,
      :num_required, :num_optional, :num_total

    def initialize(args, g)
      @required_args = []
      @optional_args = []
      @rest_arg = nil
      @block_arg = nil

      next_is_rest = false
      next_is_block = false

      args.each do |arg|
        g.compile_error "Unexpected arguments after block argument" if @block_arg

        case arg
        when AST::ArrayLiteral
          g.compile_error "Arguments in fn form must be identifiers" unless arg[0].is_a? AST::Identifier
          g.compile_error "Arguments in fn form can have only one optional value" unless arg.elements.length == 2

          optional_args << [arg[0].name, arg[1]]
        when AST::Identifier
          if arg.name == :& && !@block_arg
            g.compile_error "Can't have two rest arguments in one overload" if @rest_arg
            next_is_rest = true
          elsif arg.name == :|
            g.compile_error "Can't have two block arguments in one overload" if @block_arg
            next_is_block = true
          elsif next_is_rest
            @rest_arg = arg.name
            next_is_rest = false
          elsif next_is_block
            @block_arg = arg.name
            next_is_block = false
          else
            g.compile_error "Unexpected arguments after rest argument" if @rest_arg
            g.compile_error "Optional arguments in fn form must be last" if @optional_args.any?
            @required_args << arg.name
          end
        else
          g.compile_error "Arguments in fn form must be identifiers or 2-element arrays"
        end
      end

      g.compile_error "Expected identifier following & in argument list" if next_is_rest
      g.compile_error "Expected identifier following | in argument list" if next_is_block

      @num_required = @required_args.length
      @num_optional = @optional_args.length
      @num_total = @num_required + @num_optional
    end
  end

  Overload = Struct.new(:arglist, :body)

  # (fn name? [args*] body*)
  # (fn name? [args* | block] body*)
  # (fn name? [args* & rest] body*)
  # (fn name? [args* & rest | block] body*)
  # (fn name? ([args*] body*) ... ([args*] body*))
  SpecialForm.define(:fn) do |g, args|
    fn_name = args.shift.name if args.first.is_a? AST::Identifier

    overloads = []
    # The overload that a (recur ...) in a variadic overload must jump to if
    # the variadic argument list passed is empty, and a matching non-variadic
    # overload exists.
    secondary_recur_overload = nil

    case args.first
    when AST::List
      # This is the multi-arity form (fn name? ([args*] body*) ... ([args*] body*))
      args.each do |overload|
        # Each overload is of the form ([args*] body*)
        g.compile_error "Expected an arity overload (a list)" unless overload.is_a? AST::List
        arglist, *body = overload.elements
        g.compile_error "Argument list in overload must be an array literal" unless arglist.is_a? AST::ArrayLiteral
        arglist = ArgList.new(arglist.elements, g)
        overloads << Overload.new(arglist, body)
      end
    when AST::ArrayLiteral
      # This is the single-arity form (fn name? [args*] body*)
      arglist, *body = args
      arglist = ArgList.new(arglist.elements, g)
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

        # If there is a normal overload with the same number of total
        # arguments as the variadic overload, then a (recur ...) in the
        # variadic overload may need to jump to the non-variadic overload.
        if variadic_arglist.num_total == normals.last.arglist.num_total
          secondary_recur_overload = normals.length - 1
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

    fn_scope = AST::FnScope.new(g.scope, fn_name)

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
        fn.push_cpath_top
        fn.find_const :ArgumentError
        fn.push_literal "No matching overload"
        fn.string_dup
        fn.send :new, 1
        fn.raise_exc
      end
    end

    overloads.each_with_index do |overload, i|
      arglist, body = overload.arglist, overload.body
      overload_scope = AST::OverloadScope.new(fn_scope)
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

        value.bytecode(fn)
        fn.set_local arg_index
        fn.pop

        next_optional.set!
        next_optional = fn.new_label
      end

      if arglist.rest_arg
        # Allocate the slot for the rest argument
        overload_scope.new_local(arglist.rest_arg)
        overload_scope.splat = true

        # If there is another overload with the same number of arguments,
        # excluding the variadic argument, a (recur ...) in this variadic
        # overload may need to jump to that one (if recur is given an empty
        # list for the variadic argument). Store the other overload's label in
        # this variadic overload scope so (recur ...) can find it.
        if secondary_recur_overload
          overload_scope.secondary_loop_label =
            overload_labels[secondary_recur_overload]
        end
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

    g.push_cpath_top
    g.find_const :Kernel
    g.create_block fn
    g.send_with_block :lambda, 0
    g.set_local fn_scope.self_reference.slot if fn_name
  end

  # (try body* (rescue name|[name condition*] body*)* (ensure body*)?)
  SpecialForm.define(:try) do |g, args|
    body = []
    rescue_clauses = []
    ensure_clause = nil

    if args.last.is_a?(AST::List) && args.last[0].is_a?(AST::Identifier) && args.last[0].name == :ensure
      ensure_clause = args.pop[1..-1] # Chop off the ensure identifier
    end

    args.each do |arg|
      if arg.is_a?(AST::List) && arg[0].is_a?(AST::Identifier) && arg[0].name == :rescue
        rescue_clauses << arg[1..-1] # Chop off the rescue identifier
      else
        g.compile_error "Unexpected form after rescue clause" unless rescue_clauses.empty?
        body << arg
      end
    end

    # Set up ensure
    if ensure_clause
      ensure_ex = g.new_label
      ensure_ok = g.new_label
      g.setup_unwind ensure_ex, 1
    end

    ex = g.new_label
    done = g.new_label

    g.push_exception_state
    g.set_stack_local(ex_state = g.new_stack_local)
    g.pop

    # Evaluate body
    g.setup_unwind ex, 0
    SpecialForm[:do].bytecode(g, body)
    g.pop_unwind
    g.goto done

    # Body raised an exception
    ex.set!

    # Save exception state for re-raise
    g.push_exception_state
    g.set_stack_local(raised_ex_state = g.new_stack_local)
    g.pop

    # Push exception for rescue conditions
    g.push_current_exception

    rescue_clauses.each do |clause|
      # Parse either (rescue e body) or (rescue [e Exception] body)
      if clause[0].is_a?(AST::Identifier)
        name = clause.shift
        conditions = []
      elsif clause[0].is_a?(AST::ArrayLiteral)
        conditions = clause.shift.elements
        name = conditions.first
        conditions = conditions.drop(1)
        g.compile_error "Expected identifier as first form of rescue clause binding" unless name.is_a?(AST::Identifier)
      else
        g.compile_error "Expected identifier or array as first form of rescue clause"
      end

      # Default to StandardError for (rescue e body) and (rescue [e] body)
      conditions << AST::Identifier.new(name.line, :StandardError) if conditions.empty?

      body = g.new_label
      next_rescue = g.new_label

      conditions.each do |cond|
        g.dup # The exception
        cond.bytecode(g)
        g.swap
        g.send :===, 1
        g.git body
      end
      g.goto next_rescue

      # This rescue condition matched
      body.set!

      # Create a new scope to hold the exception
      scope = AST::LetScope.new(g.scope)
      g.scopes << scope

      # Exception is still on the stack
      g.set_local scope.new_local(name)
      g.pop

      SpecialForm[:do].bytecode(g, clause)

      # Yay!
      g.clear_exception
      g.goto done

      g.scopes.pop

      # Rescue condition did not match
      next_rescue.set!
    end

    # No rescue conditions matched, re-raise
    g.pop # The exception

    # Re-raise the original exception
    g.push_stack_local raised_ex_state
    g.restore_exception_state
    g.reraise

    # Body executed without exception or was rescued
    done.set!

    g.push_stack_local raised_ex_state
    g.restore_exception_state

    if ensure_clause
      g.pop_unwind
      g.goto ensure_ok

      # Body raised an exception
      ensure_ex.set!

      # Execute ensure clause
      g.push_exception_state
      ensure_clause.each do |expr|
        expr.bytecode(g)
        g.pop # Ensure cannot return anything
      end
      g.restore_exception_state

      g.reraise

      # Body executed without exception or was rescued
      ensure_ok.set!

      # Execute ensure clause
      ensure_clause.each do |expr|
        expr.bytecode(g)
        g.pop
      end
    end
  end
end
