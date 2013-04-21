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
    g.compile_error "Too few arguments to #{type}" if args.count < 1
    g.compile_error "First argument to #{type} must be an array literal" unless args.first.is_a? Array

    bindings, body = args.first, args.rest

    g.compile_error "Bindings array for #{type} must contain an even number of forms" if bindings.length.odd?

    scope = LetScope.new(g.scope)
    g.scopes << scope

    bindings.each_slice(2) do |id, value|
      g.compile_error "Binding targets in #{type} must be identifiers" unless id.is_a? Identifier

      Compiler.bytecode(g, value)
      g.set_local scope.new_local(id)
      g.pop
    end

    if type == :loop
      scope.loop_label = g.new_label
      scope.loop_label.set!
    end

    SpecialForm[:do].bytecode(g, body)

    g.scopes.pop
  end
end

%w[def do dot fn if let loop quote recur try].each do |r|
  require "apricot/special_forms/#{r}"
end
