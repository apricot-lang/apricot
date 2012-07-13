%w[ast parser compiler stages printers special_forms].map {|r| require "apricot/#{r}" }
