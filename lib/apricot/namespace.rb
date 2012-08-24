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

    attr_reader :vars, :fns, :macros

    def initialize
      @vars = {}
      @fns = Set[]
      @macros = Set[]
    end

    def set_var(name, val)
      @vars[name] = val

      case val
      when Proc, Proc::Method, Method, UnboundMethod
        if @fns.include?(name) || !self.respond_to?(name)
          @fns.add name
          define_singleton_method(name, val)
        end
      else
        if @fns.include?(name)
          @fns.delete name
          singleton_class.send(:undef_method, name)
        end
      end
    end

    def get_var(name)
      raise NameError, "Undefined variable '#{name}' on #{self}" unless @vars.include? name
      @vars[name]
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
