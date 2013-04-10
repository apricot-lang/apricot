module Apricot
  class Cons
    include Seq

    def initialize(head, tail)
      @head = head
      @tail = tail.seq
    end

    def first
      @head
    end

    def next
      if @tail
        @tail
      else
        nil
      end
    end

    def each
      yield first
      @tail.each {|x| yield x }
    end
  end
end
