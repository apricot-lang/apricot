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

      if @name =~ /\A(?:[A-Z]\w*::)*[A-Z]\w*\z/
        @constant = true
        @const_names = @name.to_s.split('::').map(&:to_sym)
      end
    end

    def constant?
      @constant
    end

    def const_names
      raise "#{@name} is not a constant" unless constant?
      @const_names
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
      when :true, :false, :nil, /\A(?:\+|-)?\d/
        # Use arbitrary identifier syntax for identifiers that would otherwise
        # be parsed as keywords or numbers
        str = @name.to_s.gsub(/(\\.)|\|/) { $1 || '\|' }
        "#|#{str}|"
      when /\A#{Apricot::Parser::IDENTIFIER}+\z/
        @name.to_s
      else
        str = @name.to_s.inspect[1..-2]
        str.gsub!(/(\\.)|\|/) { $1 || '\|' }
        "#|#{str}|"
      end
    end

    def to_s
      @name.to_s
    end
  end
end
