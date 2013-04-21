require 'redcard'
RedCard.verify "1.9", :rubinius => "2.0"

require 'set'

%w[
version misc namespace seq cons list identifier ruby_ext reader compiler
scopes variables macroexpand generator special_forms errors code_loader boot
].each {|r| require "apricot/#{r}" }
