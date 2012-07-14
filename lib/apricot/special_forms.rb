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

  SpecialForm.define(:'.') do |g, args|
    raise ArgumentError, "Too few arguments to send expression, expecting (. reciever method ...)" if args.length < 2
    raise TypeError, "Method in send expression must be an identifier" unless args[1].is_a? AST::Identifier

    receiver, method, margs = args[0], args[1].name, args[2..-1]

    receiver.bytecode(g)
    margs.each {|a| a.bytecode(g) }
    g.send method, margs.length
  end

  SpecialForm.define(:def) do |g, args|
    raise ArgumentError, "Too few arguments to def" if args.length < 1
    raise ArgumentError, "Too many arguments to def" if args.length > 2
    raise ArgumentError, "First argument to def must be an identifier" unless args[0].is_a?(AST::Identifier)

    name = args[0].name
    value = args[1]

    value ? value.bytecode(g) : g.push_nil

    g.set_local 0
    g.local_count = 1
    g.local_names = [name]
  end

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

  SpecialForm.define(:quote) do |g, args|
    raise ArgumentError, "Too few arguments to quote" if args.length < 1
    raise ArgumentError, "Too many arguments to quote" if args.length > 1

    g.push_literal args.first
  end
end
