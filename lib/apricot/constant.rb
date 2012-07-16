module Apricot
  class Constant
    attr_reader :names

    def initialize(*names)
      @names = names
    end

    def name
      @names.join '::'
    end

    def ==(other)
      return false unless other.is_a? Constant
      @names == other.names
    end

    alias_method :eql?, :==

    def hash
      @names.hash
    end

    def inspect
      "#<#{self.class.name} #{name}>"
    end

    alias_method :to_s, :inspect
  end
end
