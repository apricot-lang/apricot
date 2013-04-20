require 'bundler/setup'
require 'rspec'

require 'simplecov'

SimpleCov.configure do
  add_filter 'spec/'
  add_filter 'kernel/' # SimpleCov doesn't understand Apricot code

  add_group 'Compiler' do |src|
    ['code_loader.rb',
     'compiler.rb',
     'errors.rb',
     'generator.rb',
     'reader.rb'].any? {|f| src.filename.end_with? "apricot/#{f}" }
  end
  add_group 'AST', 'ast'
  add_group 'Special Forms', 'special_forms'
  add_group 'Runtime' do |src|
    ['boot.rb',
     'cons.rb',
     'identifier.rb',
     'list.rb',
     'macroexpand.rb',
     'misc.rb',
     'namespace.rb',
     'ruby_ext.rb',
     'seq.rb'].any? {|f| src.filename.end_with? "apricot/#{f}" }
  end
end
SimpleCov.start unless ENV['TRAVIS']

require 'apricot'
include Apricot
