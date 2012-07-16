%w[ast parser compiler stages printers special_forms list identifier constant].map {|r| require "apricot/#{r}" }
