module Apricot
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
