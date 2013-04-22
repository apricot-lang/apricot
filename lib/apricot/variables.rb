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

  class NamespaceReference
    def initialize(name, ns = nil)
      @name = name
      @ns = ns || Apricot.current_namespace
    end

    def bytecode(g)
      if @ns.is_a?(Namespace) && !@ns.has_var?(@name)
        g.compile_error "Unable to resolve name #{@name} in namespace #{@ns}"
      end

      ns_id = Identifier.intern(@ns.name)
      g.push_const ns_id.const_names.first
      ns_id.const_names.drop(1).each {|n| g.find_const(n) }

      g.push_literal @name

      if @ns.is_a? Namespace
        g.send :get_var, 1
      else # @ns is a regular Ruby module
        g.send :method, 1
      end
    end

    def meta
      @ns.is_a?(Namespace) && @ns.vars[@name] && @ns.vars[@name].apricot_meta
    end

    def fn?
      @ns.is_a?(Namespace) && @ns.fns.include?(@name)
    end

    def method?
      !@ns.is_a?(Namespace) && @ns.respond_to?(@name)
    end
  end
end
