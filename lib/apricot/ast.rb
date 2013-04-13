%w[node literals identifier list scopes variables toplevel].each do |r|
  require "apricot/ast/#{r}"
end
