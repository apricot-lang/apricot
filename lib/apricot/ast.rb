%w[node literals identifier list scopes variables].each do |r|
  require "apricot/ast/#{r}"
end
