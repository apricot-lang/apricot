module Apricot
  # Every seq should include this module and define 'first' and 'next'
  # methods. A seq may redefine 'rest' and 'each' if there is a more efficient
  # way to implement them.
  #
  # 'first' should return the first item in the seq.
  # 'next' should return a seq of the rest of the items in the seq, or nil
  #   if there are no more items.
  module Seq
    include Enumerable
    include Comparable

    def rest
      self.next || List::EMPTY_LIST
    end

    def each
      s = self

      while s
        yield s.first
        s = s.next
      end

      self
    end

    def to_seq
      self
    end

    def empty?
      false
    end

    def last
      s = self

      while s.next
        s = s.next
      end

      s.first
    end

    def cons(x)
      Cons.new(x, self)
    end

    def <=>(other)
      return unless other.is_a?(Seq) || other.nil?
      s, o = self, other

      while s && o
        comp = s.first <=> o.first
        return comp unless comp == 0
        s = s.next
        o = o.next
      end

      if s
        1
      elsif o
        -1
      else
        0
      end
    end

    alias_method :eql?, :==

    def hash
      hashes = map {|x| x.hash }
      hashes.reduce(hashes.size) {|acc,hash| acc ^ hash }
    end

    def to_s
      str = '('
      each {|x| str << x.apricot_inspect << ' ' }
      str.chop!
      str << ')'
    end

    alias_method :inspect, :to_s
  end
end
