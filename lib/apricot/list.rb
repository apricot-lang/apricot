module Apricot
  # A linked list implementation representing (a b c) syntax in Apricot
  class List
    include Seq

    def self.[](*args)
      list = EMPTY_LIST
      args.reverse_each do |arg|
        list = list.cons(arg)
      end
      list
    end

    attr_reader :head, :tail, :count

    def initialize(head, tail)
      @head = head
      @tail = tail || EMPTY_LIST
      @count = tail ? tail.count + 1 : 1
    end

    def cons(x)
      List.new(x, self)
    end

    def initialize_copy(other)
      super
      @tail = other.tail.dup if other.tail && !other.tail.empty?
    end

    private :initialize_copy

    def to_list
      self
    end

    def first
      @head
    end

    def next
      @tail.empty? ? nil : @tail
    end

    def to_seq
      self
    end

    def inspect
      return '()' if empty?

      str = '('
      each {|x| str << x.apricot_inspect << ' ' }
      str.chop!
      str << ')'
    end

    alias_method :to_s, :inspect

    class EmptyList < List
      def initialize
        @count = 0
      end

      def each
      end

      def empty?
        true
      end

      def first
        nil
      end

      def next
        nil
      end
    end

    EMPTY_LIST = EmptyList.new
  end
end
