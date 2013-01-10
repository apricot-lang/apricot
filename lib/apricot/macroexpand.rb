module Apricot
  def self.macroexpand(form)
    ex = macroexpand_1(form)
    ex.equal?(form) ? ex : macroexpand(ex)
  end

  def self.macroexpand_1(form)
    return form unless form.is_a? List

    callee = form.first
    return form unless callee.is_a? Identifier

    name = callee.name
    name_s = name.to_s
    args = form.tail

    # Handle the (.method receiver args*) send expression form
    if name.length > 1 && name_s.start_with?('.') && name_s != '..'
      raise ArgumentError, "Too few arguments to send expression, expecting (.method receiver ...)" if args.empty?

      dot = Identifier.intern(:'.')
      method = Identifier.intern(name_s[1..-1])
      List[dot, args.first, method, *args.tail]
    elsif Apricot.current_namespace.macros.include? name
      Apricot.current_namespace.get_var(name).call(*args)
    else
      form
    end
  end
end
