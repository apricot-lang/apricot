require 'rational'

%w[ast parser compiler stages printers special_forms list identifier constant].each {|r| require "apricot/#{r}" }
