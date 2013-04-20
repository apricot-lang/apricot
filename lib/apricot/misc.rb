# This file contains some things that are used in a bunch of places and don't
# fit anywhere in particular.

module Apricot
  # TODO: Should this counter be thread-local?
  @gensym = 0

  def self.gensym(prefix = 'g')
    @gensym += 1
    Identifier.intern("#{prefix}__#{@gensym}")
  end
end
