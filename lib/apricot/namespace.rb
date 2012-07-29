module Apricot
  class Namespace < Module
    def self.find_or_create(constant)
      ns = constant.names.reduce(Object) do |mod, name|
        if mod.const_defined? name
          next_mod = mod.const_get name
          raise TypeError, "#{mod}::#{name} (#{next_mod}) is not a Module" unless next_mod.is_a? Module
          next_mod
        else
          mod.const_set(name, Namespace.new)
        end
      end

      raise TypeError, "#{constant.name} is not a Namespace" unless ns.is_a? Namespace

      ns
    end

    attr_accessor :vars

    def initialize
      @vars = {}
    end

    def set_var(name, val)
      @vars[name] = val
    end

    def get_var(name)
      raise NameError, "Undefined variable '#{name}' on #{self}" unless @vars.include? name
      @vars[name]
    end
  end

  Core = Namespace.new
  Core.set_var(:"*ns*", Core)
  Core.set_var(:"in-ns", lambda do |constant|
    Apricot.current_namespace = Namespace.find_or_create constant
  end)

  class << self
    def current_namespace
      Core.get_var(:"*ns*")
    end

    def current_namespace=(mod)
      Core.set_var(:"*ns*", mod)
    end
  end
end
