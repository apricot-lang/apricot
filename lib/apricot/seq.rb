module Apricot
  module Seq
    include Enumerable

    def rest
      self.next || Apricot::List::EmptyList
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

    def to_s
      str = '('
      each {|x| str << x.apricot_inspect << ' ' }
      str.chop!
      str << ')'
    end

    alias_method :inspect, :to_s
  end
end
