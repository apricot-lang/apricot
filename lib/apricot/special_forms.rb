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
  # TODO: block argument passing
  # TODO: (. receiver (method args*)) form to ease the writing of the .. macro
  SpecialForm.define(:'.') do |g, args|
    raise ArgumentError, "Too few arguments to send expression, expecting (. receiver method ...)" if args.length < 2
    raise TypeError, "Method in send expression must be an identifier" unless args[1].is_a? AST::Identifier

    receiver, method, *margs = *args

    receiver.bytecode(g)
    margs.each {|a| a.bytecode(g) }
    g.send method.name, margs.length
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

  # (let [binding*] body*) where binding is an identifier followed by a value
  SpecialForm.define(:let) do |g, args|
    raise ArgumentError, "Too few arguments to let" if args.length < 1
    raise TypeError, "First argument to let must be an array literal" unless args.first.is_a? AST::ArrayLiteral

    bindings = args.shift.elements

    raise ArgumentError, "Bindings array for let must contain an even number of forms" if bindings.length.odd?

    scope = AST::LetScope.new
    scope.parent = g.state.scope
    g.push_state scope

    bindings.each_slice(2) do |id, value|
      raise TypeError, "Binding targets in let must be identifiers" unless id.is_a? AST::Identifier

      value.bytecode(g)
      scope.new_local(id.name).reference.set_bytecode(g)
      g.pop
    end

    SpecialForm[:do].bytecode(g, args)

    g.pop_state
  end
end
