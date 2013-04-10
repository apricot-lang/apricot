class Object
  attr_accessor :apricot_meta

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

  def seq
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

  def apricot_call(key)
    self[key]
  end

  alias_method :apricot_str, :apricot_inspect
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

  def [](elem)
    elem if self.include? elem
  end

  alias_method :apricot_call, :[]
  alias_method :apricot_str, :apricot_inspect
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

    if str =~ /\A#{Apricot::Parser::IDENTIFIER}+\z/
      ":#{str}"
    else
      ":#{str.inspect}"
    end
  end

  def apricot_call(o)
    o[self]
  end
end

module Enumerable
  def to_list
    list = Apricot::List::EmptyList
    reverse_each {|x| list = list.cons(x) }
    list
  end
end

class NilClass
  include Enumerable

  def each
  end

  # Seq Methods
  # Many functions that return seqs occasionally return nil, so it's
  # convenient if nil can respond to some of the same methods as seqs.

  def seq
    nil
  end

  def first
    nil
  end

  def next
    nil
  end

  def rest
    Apricot::List::EmptyList
  end
end
