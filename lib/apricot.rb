require 'rational'
require 'set'

# TODO: Move gensym to a more appropriate file
module Apricot
  @gensym = 0

  def self.gensym(prefix = 'g')
    :"#{prefix}__#{@gensym += 1}"
  end
end

%w[parser compiler ast generator stages printers locals special_forms list
identifier constant ruby_ext].each {|r| require "apricot/#{r}" }
