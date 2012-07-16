%w[ast parser compiler stages printers special_forms list identifier].map do |r|
  require "apricot/#{r}"
end
