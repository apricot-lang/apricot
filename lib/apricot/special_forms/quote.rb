module Apricot
  # (quote form)
  SpecialForm.define(:quote) do |g, args|
    g.compile_error "Too few arguments to quote" if args.length < 1
    g.compile_error "Too many arguments to quote" if args.length > 1

    args.first.quote_bytecode(g)
  end
end
