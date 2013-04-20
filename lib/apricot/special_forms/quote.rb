module Apricot
  # (quote form)
  SpecialForm.define(:quote) do |g, args|
    g.compile_error "Too few arguments to quote" if args.count < 1
    g.compile_error "Too many arguments to quote" if args.count > 1

    Compiler.bytecode(g, args.first, true)
  end
end
