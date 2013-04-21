module Apricot
  # (def name value?)
  SpecialForm.define(:def) do |g, args|
    g.compile_error "Too few arguments to def" if args.count < 1
    g.compile_error "Too many arguments to def" if args.count > 2

    id, value = *args

    g.compile_error "First argument to def must be an identifier" unless id.is_a? Identifier

    if id.constant?
      if id.const_names.length == 1
        g.push_scope
      else
        g.push_const id.const_names[0]
        id.const_names[1..-2].each {|n| g.find_const n }
      end

      g.push_literal id.const_names.last
      Compiler.bytecode(g, value)
      g.send :const_set, 2
    else
      g.compile_error "Can't change the value of self" if id.name == :self

      g.push_const :Apricot
      g.send :current_namespace, 0
      g.push_literal id.name
      Compiler.bytecode(g, value)
      g.send :set_var, 2
    end
  end
end
