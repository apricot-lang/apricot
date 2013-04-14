require 'redcard'
RedCard.verify "1.9", :rubinius => "2.0"

require 'set'

%w[
version misc parser compiler ast macroexpand generator special_forms errors
seq cons list identifier ruby_ext namespace boot
].each {|r| require "apricot/#{r}" }
