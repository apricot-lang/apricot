module Apricot
  # (recur args*)
  # Rebinds the arguments of the nearest enclosing loop or fn and jumps to the
  # top of the loop/fn. Argument rebinding is done in parallel (rebinding a
  # variable in a recur will not affect uses of that variable in the other
  # recur bindings.)
  SpecialForm.define(:recur) do |g, args|
    target = g.scope.find_recur_target
    g.compile_error "No recursion target found for recur" unless target

    g.compile_error "Can only recur from tail position" unless g.tail_position?

    vars = target.variables.values
    g.compile_error "Arity of recur does not match enclosing loop or fn" unless vars.length == args.count

    args.each {|arg| Compiler.bytecode(g, arg) }

    vars.reverse_each do |var|
      g.set_local var
      g.pop
    end

    g.check_interrupts
    g.goto target.loop_label
  end
end
