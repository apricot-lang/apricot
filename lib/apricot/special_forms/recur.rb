module Apricot
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

    vars.reverse_each do |var|
      g.set_local var
      g.pop
    end

    g.check_interrupts
    g.goto target.loop_label
  end
end