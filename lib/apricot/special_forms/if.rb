module Apricot
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
end
