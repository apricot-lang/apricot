module Apricot
  class LocalReference
    attr_reader :slot, :depth

    def initialize(slot, depth = 0)
      @slot = slot
      @depth = depth
    end

    def bytecode(g)
      if @depth == 0
        g.push_local @slot
      else
        g.push_local_depth @depth, @slot
      end
    end
  end

  class QualifiedReference
    def initialize(name, qualifier)
      unless qualifier.is_a? Module # Namespaces are Modules as well.
        raise ArgumentError, "qualifier for #{self.class} must be a Namespace or Module"
      end

      @name = name
      @qualifier = qualifier
      @on_namespace = qualifier.is_a? Namespace
    end

    def bytecode(g)
      if @qualifier.is_a?(Namespace) && !@qualifier.has_var?(@name)
        g.compile_error "Unable to resolve name #{@name} in namespace #{@qualifier}"
      end

      ns_id = Identifier.intern(@qualifier.name)
      g.push_const ns_id.const_names.first
      ns_id.const_names.drop(1).each {|n| g.find_const(n) }

      g.push_literal @name

      if on_namespace?
        g.send :get_var, 1
      else # @qualifier is a regular Ruby module
        g.send :method, 1
      end
    end

    def on_namespace?
      @on_namespace
    end

    def meta
      on_namespace? && @qualifier.vars[@name] &&
        @qualifier.vars[@name].apricot_meta
    end

    def fn?
      on_namespace? && @qualifier.fns.include?(@name)
    end

    def method?
      !on_namespace? && @qualifier.respond_to?(@name)
    end
  end
end
