%w[scopes variables].each do |r|
  require "apricot/ast/#{r}"
end
