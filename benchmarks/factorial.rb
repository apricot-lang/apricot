$LOAD_PATH.unshift(File.expand_path('../../lib', __FILE__))
require 'apricot'

begin
  require 'benchmark/ips'
rescue LoadError
  $stderr.puts "The benchmark-ips gem is not installed."
  exit 1
end

ruby_loop = lambda do |n|
  cnt = n
  acc = 1

  while cnt > 0
    acc *= cnt
    cnt -= 1
  end

  acc
end

apricot_loop = Apricot::Compiler.eval <<CODE
  (fn [n]
    (loop [n n acc 1]
      (if (pos? n)
        (recur (dec n) (* n acc))
        acc)))
CODE

ruby_reduce = lambda do |n|
  (1..n).reduce(1, :*)
end

apricot_reduce_1 = Apricot::Compiler.eval <<CODE
  (fn [n] (.reduce (Range. 1 n) 1 :*))
CODE

apricot_reduce_2 = Apricot::Compiler.eval <<CODE
  (fn [n] (reduce * (Range. 1 n)))
CODE

n = 100

Benchmark.ips do |x|
  x.report("ruby loop")        { ruby_loop.call(n) }
  x.report("apricot loop")     { apricot_loop.call(n) }
  x.report("ruby reduce")      { ruby_reduce.call(n) }
  x.report("apricot reduce 1") { apricot_reduce_1.call(n) }
  x.report("apricot reduce 2") { apricot_reduce_2.call(n) }
end
