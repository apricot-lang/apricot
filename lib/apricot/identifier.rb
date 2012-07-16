module Apricot
  class Identifier
    attr_reader :name

    def initialize(name)
      @name = name
    end

    def ==(other)
      return false unless other.is_a? Identifier
      @name == other.name
    end

    alias_method :eql?, :==

    def hash
      @name.hash
    end

    def inspect
      @name.to_s
    end

    alias_method :to_s, :inspect
  end
end
