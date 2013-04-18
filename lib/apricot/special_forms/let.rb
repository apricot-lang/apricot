module Apricot
  # (let [binding*] body*) where binding is an identifier followed by a value
  SpecialForm.define(:let) do |g, args|
    # loop and let share a lot of code. See special_forms.rb for the shared
    # definition.
    let(g, args, :let)
  end
end
