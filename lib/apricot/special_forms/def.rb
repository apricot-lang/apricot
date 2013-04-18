module Apricot
  # (def name value?)
  SpecialForm.define(:def) do |g, args|
    g.compile_error "Too few arguments to def" if args.length < 1
    g.compile_error "Too many arguments to def" if args.length > 2

    target, value = *args

    g.compile_error "First argument to def must be an identifier" unless target.is_a? AST::Identifier

    value ||= AST::Literal.new(0, :nil)
    target.assign_bytecode(g, value)
  end
end
