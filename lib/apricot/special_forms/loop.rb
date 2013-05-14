module Apricot
  # (loop [binding*] body*) where binding is an identifier followed by a value
  # Just like let but also introduces a loop target for (recur ...)
  SpecialForm.define(:loop) do |g, args|
    # loop and let share a lot of code. See special_forms.rb for the shared
    # definition.
    g.tail_position = true
    let(g, args, :loop)
  end
end
