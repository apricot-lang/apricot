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

  SpecialForm.define(:def) do |g, args|
    raise ArgumentError, "Too few arguments to def" if args.length < 1
    raise ArgumentError, "Too many arguments to def" if args.length > 2
    raise ArgumentError, "First argument to def must be an Identifier" unless args[0].is_a?(AST::Identifier)

    name = args[0].name
    value = args[1]

    if value
      value.bytecode(g)
    else
      g.push_nil
    end

    g.set_local 0
    g.local_count = 1
    g.local_names = [name]
  end
end
