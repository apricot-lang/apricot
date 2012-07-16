%w[ast parser compiler stages printers special_forms list].map {|r| require "apricot/#{r}" }
