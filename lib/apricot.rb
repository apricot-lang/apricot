unless RUBY_VERSION.start_with?("2") && RUBY_ENGINE == "rbx" && Rubinius::VERSION.start_with?("2")
  $stderr.puts "Apricot must be run on the stable Rubinius 2.0.0 release or newer."
  exit 1
end

require 'set'

%w[
version misc namespace seq cons list identifier ruby_ext reader compiler
scopes variables macroexpand generator special_forms errors code_loader boot
].each {|r| require "apricot/#{r}" }
