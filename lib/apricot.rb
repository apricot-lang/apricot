require 'set'

%w[
version misc parser compiler ast macroexpand generator stages printers
special_forms errors seq cons list identifier ruby_ext namespace
].each {|r| require "apricot/#{r}" }

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
  Core.get_var(:ns).apricot_meta = {:macro => true}

  # TODO: add and use a proper code loader
  Apricot::Compiler.compile(File.expand_path('../../kernel/core.apr', __FILE__))

#  ::User = Namespace.new
  Apricot.current_namespace = Core
  # TODO: make Apricot::Core public vars visible in User, default to User
end
