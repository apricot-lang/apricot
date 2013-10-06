class Object
  attr_reader :apricot_meta

  def apricot_meta=(meta)
    @apricot_meta = meta unless frozen?
  end

  def apricot_inspect
    inspect
  end

  def apricot_str
    to_s
  end

  def apricot_call(*args)
    call(*args)
  end
end

class Array
  # Adapted from Array#inspect. This version prints no commas and calls
  # #apricot_inspect on its elements. e.g. [1 2 3]
  def apricot_inspect
    return '[]' if size == 0

    str = '['

    return '[...]' if Thread.detect_recursion self do
      each {|x| str << x.apricot_inspect << ' ' }
    end

    str.chop!
    str << ']'
  end

  def apricot_call(idx)
    self[idx]
  end

  alias_method :apricot_str, :apricot_inspect

  def to_seq
    if length == 0
      nil
    else
      Seq.new(self, 0)
    end
  end

  class Seq
    include Apricot::Seq

    def initialize(array, offset = 0)
      @array = array
      @offset = offset
    end

    def first
      @array[@offset]
    end

    def next
      if @offset + 1 < @array.length
        Seq.new(@array, @offset + 1)
      else
        nil
      end
    end

    def each
      @array[@offset..-1].each {|x| yield x }
    end

    def count
      @array.length - @offset
    end

    def to_a
      @array[@offset..-1]
    end
  end
end

class Hash
  # Adapted from Hash#inspect. Outputs Apricot hash syntax, e.g. {:a 1, :b 2}
  def apricot_inspect
    return '{}' if size == 0

    str = '{'

    return '{...}' if Thread.detect_recursion self do
      each_item do |item|
        str << item.key.apricot_inspect
        str << ' '
        str << item.value.apricot_inspect
        str << ', '
      end
    end

    str.shorten!(2)
    str << '}'
  end

  def apricot_call(key, default = nil)
    fetch(key, default)
  end

  alias_method :apricot_str, :apricot_inspect

  def to_seq
    each_pair.to_a.to_seq
  end
end

class Set
  def apricot_inspect
    return '#{}' if size == 0

    str = '#{'

    return '#{...}' if Thread.detect_recursion self do
      each {|x| str << x.apricot_inspect << ' ' }
    end

    str.chop!
    str << '}'
  end

  def apricot_call(elem, default = nil)
    include?(elem) ? elem : default
  end

  alias_method :apricot_str, :apricot_inspect

  def to_seq
    to_a.to_seq
  end
end

class Rational
  def apricot_inspect
    if @denominator == 1
      @numerator.to_s
    else
      to_s
    end
  end

  alias_method :apricot_str, :apricot_inspect
end

class Regexp
  def apricot_inspect
    "#r#{inspect}"
  end

  alias_method :apricot_str, :apricot_inspect
end

class Symbol
  def apricot_inspect
    str = to_s

    if str =~ /\A#{Apricot::Reader::IDENTIFIER}+\z/
      ":#{str}"
    else
      ":#{str.inspect}"
    end
  end

  def apricot_call(obj, default = nil)
    if obj.is_a?(Hash) || obj.is_a?(Set)
      obj.apricot_call(self, default)
    else
      nil
    end
  end
end

class Range
  def to_seq
    if first > last || (first == last && exclude_end?)
      nil
    else
      Seq.new(first, last, exclude_end?)
    end
  end

  class Seq
    include Apricot::Seq

    def initialize(first, last, exclusive)
      @first = first
      @last = last
      @exclusive = exclusive
    end

    def first
      @first
    end

    def next
      next_val = @first.succ

      if @first == @last || (next_val == @last && @exclusive)
        nil
      else
        Seq.new(next_val, @last, @exclusive)
      end
    end

    def each
      prev = nil
      val = @first

      until prev == @last || (val == @last && @exclusive)
        yield val
        prev = val
        val = val.succ
      end

      self
    end
  end
end

module Enumerable
  def to_list
    list = Apricot::List::EMPTY_LIST
    reverse_each {|x| list = list.cons(x) }
    list
  end
end

class NilClass
  include Enumerable

  def each
  end

  def empty?
    true
  end

  # Seq Methods
  # Many functions that return seqs occasionally return nil, so it's
  # convenient if nil can respond to some of the same methods as seqs.

  def to_seq
    nil
  end

  def first
    nil
  end

  def next
    nil
  end

  def rest
    Apricot::List::EMPTY_LIST
  end
end
