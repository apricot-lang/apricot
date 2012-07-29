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

  FastMathOps = {
    :+    => :meta_send_op_plus,
    :-    => :meta_send_op_minus,
    :==   => :meta_send_op_equal,
    :===  => :meta_send_op_tequal,
    :<    => :meta_send_op_lt,
    :>    => :meta_send_op_gt
  }

  # (. receiver method args*)
  # (. receiver method args* | block)
  # (. receiver (method args*))
  # (. receiver (method args* | block))
  SpecialForm.define(:'.') do |g, args|
    raise ArgumentError, "Too few arguments to send expression, expecting (. receiver method ...)" if args.length < 2

    receiver, method_or_list = args.shift(2)

    # Handle the (. receiver (method args*)) form
    if method_or_list.is_a? AST::List
      method = method_or_list.elements.shift

      raise ArgumentError, "Invalid send expression, expecting (. receiver (method ...))" unless args.empty?

      args = method_or_list.elements
    else
      method = method_or_list
    end

    raise TypeError, "Method in send expression must be an identifier" unless method.is_a? AST::Identifier

    block_arg = nil

    if i = args.find_index {|arg| arg.is_a?(AST::Identifier) && arg.name == :| }
      block_arg = args[i + 1]

      raise ArgumentError, "Expected block argument after | in send expression" unless block_arg
      raise ArgumentError, "Unexpected arguments after block argument in send expression" if args[i + 2]

      args = args[0...i]
    end

    receiver.bytecode(g)

    if block_arg
      args.each {|a| a.bytecode(g) }

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

      g.send_with_block method.name, args.length

    elsif args.length == 1 && op = FastMathOps[method.name]
      args.each {|a| a.bytecode(g) }
      g.__send__ op, g.find_literal(method.name)

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
    raise ArgumentError, "Too few arguments to def" if args.length < 1
    raise ArgumentError, "Too many arguments to def" if args.length > 2

    target, value = *args

    value ||= AST::NilLiteral.new(1)

    case target
    when AST::Identifier, AST::Constant
      target.assign_bytecode(g, value)
    else
      raise ArgumentError, "First argument to def must be an identifier or constant"
    end
  end

  # (if cond body else_body?)
  SpecialForm.define(:if) do |g, args|
    raise ArgumentError, "Too few arguments to if" if args.length < 2
    raise ArgumentError, "Too many arguments to if" if args.length > 3

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
    raise ArgumentError, "Too few arguments to quote" if args.length < 1
    raise ArgumentError, "Too many arguments to quote" if args.length > 1

    args.first.quote_bytecode(g)
  end

  # Code shared between let and loop. type is :let or :loop
  def self.let(g, args, type)
    raise ArgumentError, "Too few arguments to #{type}" if args.length < 1
    raise TypeError, "First argument to #{type} must be an array literal" unless args.first.is_a? AST::ArrayLiteral

    bindings = args.shift.elements

    raise ArgumentError, "Bindings array for #{type} must contain an even number of forms" if bindings.length.odd?

    scope = AST::LetScope.new(g.scope)
    g.push_scope scope

    bindings.each_slice(2) do |name, value|
      raise TypeError, "Binding targets in let must be identifiers" unless name.is_a? AST::Identifier

      value.bytecode(g)
      g.set_local scope.new_local(name)
      g.pop
    end

    if type == :loop
      scope.loop_label = g.new_label
      scope.loop_label.set!
    end

    SpecialForm[:do].bytecode(g, args)

    g.pop_scope
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
    vars = target.variables.values

    # TODO: check for fns with rest (splat) args
    raise ArgumentError, "Arity of recur does not match enclosing loop or fn" unless vars.length == args.length

    args.each {|arg| arg.bytecode(g) }

    vars.reverse_each do |var|
      g.set_local var
      g.pop
    end

    g.check_interrupts
    g.goto target.loop_label
  end

  # (fn name? [args*] body*)
  # (fn name? [args* & rest] body*)
  SpecialForm.define(:fn) do |g, args|
    name = args.shift.name if args.first.is_a? AST::Identifier

    raise TypeError, "Argument list for fn must be an array literal" unless args.first.is_a? AST::ArrayLiteral

    arg_list = args.shift.elements

    fn = g.class.new
    fn.name = name || :__fn__
    fn.file = g.file

    scope = AST::FnScope.new(g.scope)
    fn.push_scope scope

    fn.definition_line g.line
    fn.set_line g.line

    splat_index = nil

    arg_list.each_with_index do |arg, i|
      raise TypeError, "Arguments in fn form must be identifiers" unless arg.is_a? AST::Identifier

      if arg.name == :&
        splat_index = i
        break
      end

      scope.new_local(arg.name)
    end

    if splat_index
      splat_arg = arg_list[splat_index + 1] # arg after &
      raise ArgumentError, "Expected identifier following & in argument list" unless splat_arg
      raise ArgumentError, "Unexpected arguments after rest argument" if arg_list[splat_index + 2]

      scope.new_local(splat_arg.name)
      scope.splat = true
    end

    scope.loop_label = fn.new_label
    scope.loop_label.set!

    SpecialForm[:do].bytecode(fn, args)

    fn.ret
    fn.close

    fn.pop_scope
    fn.splat_index = splat_index if splat_index
    fn.local_count = scope.local_count
    fn.local_names = scope.local_names

    args_count = arg_list.length
    args_count -= 2 if splat_index # don't count the & or splat arg itself
    fn.required_args = fn.total_args = args_count

    g.push_cpath_top
    g.find_const :Kernel
    g.create_block fn
    g.send_with_block :lambda, 0
  end

  # (try body* (rescue condition name body*)* (ensure body*)?)
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
        raise ArgumentError, "Unexpected form after rescue clause" unless rescue_clauses.empty?
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
    reraise = g.new_label
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

    rescue_clauses.each_with_index do |clause, i|
      condition, name = clause.shift(2)

      body = g.new_label
      # The last rescue clause re-raises if its condition doesn't match
      next_rescue = (i == rescue_clauses.length - 1) ? reraise : g.new_label

      g.dup # The exception
      condition.bytecode(g)
      g.swap
      g.send :===, 1
      g.git body
      g.goto next_rescue

      # This rescue condition matched
      body.set!

      # Create a new scope to hold the exception
      scope = AST::LetScope.new(g.scope)
      g.push_scope scope

      # Exception is still on the stack
      g.set_local scope.new_local(name)
      g.pop

      SpecialForm[:do].bytecode(g, clause)

      # Yay!
      g.clear_exception
      g.goto done

      g.pop_scope

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
