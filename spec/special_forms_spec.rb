describe 'Apricot' do
  include CompilerSpec

  it 'compiles do forms' do
    apr('(do)').should == nil
    apr('(do 1 2 3)').should == 3
  end

  it 'compiles send forms' do
    apr('(. 1 class)').should == Fixnum
    apr('(. 1 (class))').should == Fixnum
    apr('(. "foo" append "bar")').should == 'foobar'
    apr('(. "foo" (append "bar"))').should == 'foobar'
  end

  it 'compiles send forms with block args' do
    apr('(. [1] map | :to_s)').should == ['1']
    apr('(. [1] (map | :to_s))').should == ['1']
    apr('(. [1] map | #(. % to_s))').should == ['1']
  end

  it 'compiles send forms with splat args' do
    apr('(. "foo bar baz" split & [" " 2])').should == ['foo', 'bar baz']
    apr('(. "foo bar baz" (split & [" " 2]))').should == ['foo', 'bar baz']
  end

  it 'compiles new send forms' do
    apr('(. Array new 3 1)').should == [1, 1, 1]
  end

  it 'does not compile invalid send forms' do
    bad_apr '(.)'
    bad_apr '(. 1)'
    bad_apr '(. 1 ())'
    bad_apr '(. 1 1)'
    bad_apr '(. [1] map |)'
    bad_apr '(. "" split &)'
  end

  it 'compiles if forms' do
    apr('(if true 1 2)').should == 1
    apr('(if false 1 2)').should == 2
    apr('(if true 1)').should == 1
    apr('(if false 1)').should == nil
  end

  it 'does not compile invalid if forms' do
    bad_apr '(if)'
    bad_apr '(if true)'
    bad_apr '(if true 1 2 3)'
  end

  it 'compiles let forms' do
    apr('(let [])').should == nil
    apr('(let [] 1 2 3)').should == 3
    apr('(let [a 1] a)').should == 1
    apr('(let [a 1 b a] b)').should == 1
  end

  it 'compiles nested let forms' do
    apr('(let [a 1] (let [a 2] a))').should == 2
    apr('(let [a 1] (let [b 2] a))').should == 1
    apr('(let [a 1] (let [a 2]) a)').should == 1
    apr('(let [a 1] (let [b a] b))').should == 1
  end

  it 'does not compile invalid let forms' do
    bad_apr '(let)'
    bad_apr '(let 1)'
    bad_apr '(let [a 1 b])'
    bad_apr '(let [1 2])'
  end

  it 'compiles loop forms' do
    apr('(loop [])').should == nil
    apr('(loop [a 1] a)').should == 1
    apr('(loop [a true] (if a (recur false) 1))').should == 1
  end

  it 'does not compile invalid loop forms' do
    bad_apr '(loop)'
    bad_apr '(loop 1)'
    bad_apr '(loop [a 1 b])'
    bad_apr '(loop [1 2])'
  end

  it 'compiles quote forms' do
    apr('(quote quote)').should == Identifier.intern(:quote)
  end

  it 'does not compile invalid quote forms' do
    bad_apr '(quote)'
    bad_apr '(quote 1 2)'
  end

  it 'does not compile invalid recur forms' do
    bad_apr '(recur)'
    bad_apr '(loop [] (recur 1))'
    bad_apr '(fn [[x 1]] (recur))'
    bad_apr '(fn [x & y] (recur 1))'
    bad_apr '(fn [x & y] (recur 1 2 3))'
  end

  it 'compiles try forms' do
    apr('(try)').should == nil
    apr('(try 1 2 3)').should == 3
    apr('(try 1 (rescue e 2))').should == 1
    apr('(try (Kernel/raise "") 1 (rescue e 2))').should == 2
    apr('(try (Kernel/raise "") 1 (rescue [e] 2))').should == 2
    apr('(try (Kernel/raise ArgumentError) 1 (rescue [e TypeError] 2) (rescue [e ArgumentError] 3) (rescue e 4))').should == 3
    apr('(try (Kernel/raise "") 1 (rescue e e))').should be_a(RuntimeError)
    expect { apr '(try (Kernel/raise ""))' }.to raise_error(RuntimeError)
    expect { apr '(try (Kernel/raise ArgumentError) 1 (rescue [e TypeError] 2))' }.to raise_error(ArgumentError)
  end

  it 'compiles try forms with ensure clauses' do
    apr(<<-CODE).should == []
      (let [a [1]]
        (try
          2
          (ensure (. a pop)))
        a)
    CODE
    apr(<<-CODE).should == []
      (let [a [1]]
        (try
          (Kernel/raise "")
          (rescue e 2)
          (ensure (. a pop)))
        a)
    CODE
    apr(<<-CODE).should == []
      (let [a [1]]
        (try
          (try
            (Kernel/raise "")
            (ensure (. a pop)))
          (rescue e 2))
        a)
    CODE
  end

  it 'does not compile invalid try forms' do
    bad_apr '(try (ensure) 1)'
    bad_apr '(try (rescue e e) 1)'
    bad_apr '(try (rescue 1 2))'
    bad_apr '(try (rescue [1] 2))'
  end
end
