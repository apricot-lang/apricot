$LOAD_PATH.push File.expand_path("../lib", __FILE__)
require "apricot/version"

Gem::Specification.new do |s|
  s.name        = "apricot"
  s.version     = Apricot::VERSION
  s.authors     = ["Curtis McEnroe", "Scott Olson"]
  s.email       = ["programble@gmail.com", "scott@scott-olson.org"]
  s.homepage    = "https://github.com/apricot-lang/apricot"
  s.license     = "ISC"
  s.summary     = "A Clojure-like programming language on Rubinius"
  s.description = "A compiler for a Clojure-like programming language on the Rubinius VM"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- spec/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency "rubysl", "~> 2.0"

  s.add_development_dependency "rake", "~> 10.1.0"
  s.add_development_dependency "rspec", "~> 2.14.0"
  s.add_development_dependency "simplecov", "~> 0.7.0"
  s.add_development_dependency "rubinius-coverage", "~> 2.0.3"
end

