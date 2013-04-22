$LOAD_PATH.unshift(File.expand_path('../../lib', __FILE__))
require 'apricot'

begin
	require 'benchmark/ips'
rescue LoadError
	$stderr.puts "The benchmark-ips gem is not installed."
	exit 1
end

apr = Apricot::Compiler.eval <<CODE
  #(str "hello. " 42 " is the best number")
CODE

rbx = lambda { "hello. #{42} is the best number" }

Benchmark.ips do |x|
  x.report("rbx", &rbx)
  x.report("apr", &apr)
end
