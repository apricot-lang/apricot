require 'bundler/setup'
require 'rspec'

unless Rubinius.ruby19?
  puts "Error: Apricot must be run in Ruby 1.9 mode"
  exit 1
end

require 'apricot'
