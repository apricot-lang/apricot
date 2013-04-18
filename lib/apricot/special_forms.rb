module Apricot
  class SpecialForm
    SPECIAL_FORMS = {}

    def self.[](name)
      SPECIAL_FORMS[name]
    end

    def self.define(name, &block)
      SPECIAL_FORMS[name] = new(name, block)
    end

    def initialize(name, block)
      @name = name
      @block = block
    end

    def bytecode(g, args)
      @block.call(g, args)
    end
  end

  # Code shared between let and loop. type is :let or :loop
  def self.let(g, args, type)
    g.compile_error "Too few arguments to #{type}" if args.length < 1
    g.compile_error "First argument to #{type} must be an array literal" unless args.first.is_a? AST::ArrayLiteral

    bindings = args.shift.elements

    g.compile_error "Bindings array for #{type} must contain an even number of forms" if bindings.length.odd?

    scope = AST::LetScope.new(g.scope)
    g.scopes << scope

    bindings.each_slice(2) do |name, value|
      g.compile_error "Binding targets in let must be identifiers" unless name.is_a? AST::Identifier

      value.bytecode(g)
      g.set_local scope.new_local(name)
      g.pop
    end

    if type == :loop
      scope.loop_label = g.new_label
      scope.loop_label.set!
    end

    SpecialForm[:do].bytecode(g, args)

    g.scopes.pop
  end
end

%w[def do dot fn if let loop quote recur try].each do |r|
  require "apricot/special_forms/#{r}"
end
