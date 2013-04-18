module Apricot
  class Namespace < Module
    def self.find_or_create(constant)
      ns = constant.const_names.reduce(Object) do |mod, name|
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

    attr_reader :vars, :fns, :aliases

    def initialize
      @vars = {}
      @fns = Set[]
      @aliases = {}
    end

    def set_var(name, val)
      @vars[name] = val

      val = val.to_proc if val.is_a? Method

      if val.is_a?(Proc) && (@fns.include?(name) || !self.respond_to?(name))
        @fns.add name
        define_singleton_method(name, val)
      elsif @fns.include?(name)
        @fns.delete name
        singleton_class.send(:undef_method, name)
      end

      val
    end

    def get_var(name)
      # raise may be a function defined on the namespace so we need to
      # explicitly call the Ruby raise method.
      Kernel.raise NameError,
        "Undefined variable '#{name}' on #{self}" unless has_var? name

      if var = @vars[name]
        var
      elsif ns = @aliases[name]
        ns.get_var(name)
      else
        nil
      end
    end

    def add_alias(name, ns)
      @aliases[name] = ns
    end

    def has_var?(name)
      @vars.has_key?(name) || @aliases.has_key?(name)
    end
  end

  class << self
    def current_namespace
      Core.get_var(:"*ns*")
    end

    def current_namespace=(ns)
      Core.set_var(:"*ns*", ns)
    end
  end
end
