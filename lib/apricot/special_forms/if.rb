module Apricot
  # (if cond body else_body?)
  SpecialForm.define(:if) do |g, args|
    g.compile_error "Too few arguments to if" if args.count < 2
    g.compile_error "Too many arguments to if" if args.count > 3

    cond, body, else_body = *args
    else_label = g.new_label
    end_label = g.new_label

    Compiler.bytecode(g, cond)
    g.gif else_label

    Compiler.bytecode(g, body)
    g.goto end_label

    else_label.set!
    if else_body
      Compiler.bytecode(g, else_body)
    else
      g.push_nil
    end

    end_label.set!
  end
end
