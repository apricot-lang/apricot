require 'rational'
require 'set'

# TODO: Move gensym to a more appropriate file
module Apricot
  @gensym = 0

  def self.gensym(prefix = 'g')
    :"#{prefix}__#{@gensym += 1}"
  end
end

%w[parser compiler ast generator stages printers special_forms list identifier
constant ruby_ext namespace].each {|r| require "apricot/#{r}" }
