module Apricot
  def self.macroexpand(form)
    ex = macroexpand_1(form)
    ex.equal?(form) ? ex : macroexpand(ex)
  end

  def self.macroexpand_1(form)
    return form unless form.is_a? List

    callee = form.first
    return form unless callee.is_a?(Identifier) && !callee.constant?

    name = callee.name
    name_s = name.to_s
    args = form.tail

    # Handle the (.method receiver args*) send expression form
    if name.length > 1 && name_s != '..' && name_s.start_with?('.')
      raise ArgumentError, "Too few arguments to send expression, expecting (.method receiver ...)" if args.empty?

      dot = Identifier.intern(:'.')
      method = Identifier.intern(name_s[1..-1])
      return List[dot, args.first, method, *args.tail]
    end

    # Handle the (Class. args*) shorthand new form
    if name.length > 1 && name_s != '..' && name_s.end_with?('.')
      dot = Identifier.intern(:'.')
      klass = Identifier.intern(name_s[0..-2])
      new = Identifier.intern(:new)
      return List[dot, klass, new, *args]
    end

    # Handle defined macros
    if callee.ns.is_a?(Namespace) && callee.ns.vars.include?(callee.unqualified_name)
      potential_macro = callee.ns.get_var(callee.unqualified_name)
      meta = potential_macro.apricot_meta

      if meta && meta[:macro]
        return potential_macro.call(*args)
      end
    end

    # Default case
    form
  end
end
