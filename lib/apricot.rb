require 'set'

# TODO: Move gensym and macroexpand to a more appropriate file
module Apricot
  @gensym = 0

  def self.gensym(prefix = 'g')
    :"#{prefix}__#{@gensym += 1}"
  end

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

%w[parser compiler ast generator stages printers special_forms errors list
identifier ruby_ext namespace].each {|r| require "apricot/#{r}" }

# Start "booting" apricot. Set up core namespace and load the core library.
module Apricot
  Core = Namespace.new

  Core.set_var(:"*ns*", Core)

  Core.set_var(:"in-ns", lambda do |constant|
    Apricot.current_namespace = Namespace.find_or_create constant
  end)

  Core.set_var(:ns, lambda do |constant|
    List[Identifier.intern(:"in-ns"),
      List[Identifier.intern(:quote), constant]]
  end)
  Core.macros << :ns

  # TODO: add and use a proper code loader
  file = __FILE__
  file = File.readlink(file) while File.symlink? file
  file = File.expand_path('../../kernel/core.apr', file)
  Apricot::Compiler.compile(file)

#  ::User = Namespace.new
  Apricot.current_namespace = Core
  # TODO: make Apricot::Core public vars visible in User, default to User
end
