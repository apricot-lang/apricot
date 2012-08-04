module Apricot
  class Identifier
    attr_reader :name

    @table = {}

    def self.intern(name)
      name = name.to_sym
      @table[name] ||= new(name)
    end

    private_class_method :new

    def initialize(name)
      @name = name
    end

    # Copying Identifiers is not allowed.
    def initialize_copy(other)
      raise TypeError, "copy of #{self.class} is not allowed"
    end

    private :initialize_copy

    alias_method :==, :equal?
    alias_method :eql?, :equal?

    def hash
      @name.hash
    end

    def inspect
      case @name
      when :true, :false, :nil # These would be parsed as keywords
        "#|#{@name.to_s}|"
      when /\a#{Apricot::Parser::IDENTIFIER}+\z/
        @name.to_s
      else
        "#|#{@name.to_s.inspect[1..-2]}|"
      end
    end

    def to_s
      @name.to_s
    end
  end
end
