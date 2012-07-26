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
    args.each {|a| a.bytecode(g) }

    if block_arg
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
    else
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

    scope = AST::LetScope.new
    scope.parent = g.state.scope
    g.push_state scope

    bindings.each_slice(2) do |id, value|
      raise TypeError, "Binding targets in let must be identifiers" unless id.is_a? AST::Identifier

      value.bytecode(g)
      scope.new_local(id.name).reference.set_bytecode(g)
      g.pop
    end

    if type == :loop
      scope.loop_label = g.new_label
      scope.loop_label.set!
    end

    SpecialForm[:do].bytecode(g, args)

    g.pop_state
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
  # top of the loop/fn
  SpecialForm.define(:recur) do |g, args|
    target = g.state.scope

    # Climb the scope ladder past the non-loop let bindings. We will end up on
    # a loop binding, a fn, or the top level scope.
    while target.is_a?(AST::LetScope) && !target.loop?
      target = target.parent
    end

    raise "No loop or fn target for recur found" if target.is_a?(AST::TopLevel)

    # TODO: check arity
    vars = target.variables.values
    args.each_with_index do |arg, i|
      arg.bytecode(g)
      vars[i].reference.set_bytecode(g)
      g.pop
    end

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

    scope = AST::FnScope.new
    scope.parent = g.state.scope
    fn.push_state scope

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

    fn.pop_state
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
end
