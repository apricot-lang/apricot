require 'rational'
require 'set'

%w[ast parser compiler stages printers special_forms list identifier constant
ruby_ext].each {|r| require "apricot/#{r}" }
