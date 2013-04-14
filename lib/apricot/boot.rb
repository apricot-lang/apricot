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
  Core.get_var(:ns).apricot_meta = {:macro => true}

  # TODO: add and use a proper code loader
  core_apr_file = File.expand_path('../../../kernel/core.apr', __FILE__)
  Apricot::Compiler.compile(core_apr_file)

#  ::User = Namespace.new
  Apricot.current_namespace = Core
  # TODO: make Apricot::Core public vars visible in User, default to User
end
