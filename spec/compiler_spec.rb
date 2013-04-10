describe 'Apricot' do
  def apricot(code)
    Apricot::Compiler.eval code
  end

  def bad_apricot(code)
    expect { apricot(code) }.to raise_error(CompileError)
  end

  it 'compiles an empty program' do
    apricot('').should == nil
  end

  it 'compiles false, true and nil' do
    apricot('true').should == true
    apricot('false').should == false
    apricot('nil').should == nil
  end

  it 'compiles numbers' do
    apricot('1').should == 1
    apricot('1.0').should == 1.0
    apricot('1/3').should == Rational(1, 3)
  end

  it 'compiles symbols' do
    apricot(':foo').should == :foo
  end

  it 'compiles strings' do
    apricot('"foo"').should == "foo"
  end

  it 'compiles regexes' do
    apricot('#r"foo"').should == /foo/
    apricot('#r/foo/x').should == /foo/x
    apricot('#r[foo]xim').should == /foo/xim
  end

  it 'compiles arrays' do
    apricot('[]').should == []
    apricot('[1 2 3]').should == [1, 2, 3]
  end

  it 'compiles hashes' do
    apricot('{}').should == {}
    apricot('{:foo 1, :bar 2}').should == {:foo => 1, :bar => 2}
  end

  it 'compiles sets' do
    apricot('#{}').should == Set.new
    apricot('#{:foo :foo :bar}').should == Set[:foo, :foo, :bar]
  end

  it 'compiles constants' do
    apricot('Array').should == Array
    apricot('Rubinius::Compiler').should == Rubinius::Compiler
  end

  it 'compiles call forms with data structures' do
    apricot('([:a :b] 1)').should == :b
    apricot('([:a :b] 3)').should == nil
    apricot('(#{:a :b} :b)').should == :b
    apricot('(#{:a :b} :c)').should == nil
    apricot('({:a 1} :a)').should == 1
    apricot('({:a 1} :b)').should == nil
  end

  it 'compiles symbol call forms' do
    apricot('(:a {:a 1 :b 2})').should == 1
    apricot('(:c {:a 1 :b 2})').should == nil
    apricot('(:a #{:a :b})').should == :a
    apricot('(:c #{:a :b})').should == nil
  end

  it 'compiles send forms' do
    apricot('(. 1 class)').should == Fixnum
    apricot('(. 1 (class))').should == Fixnum
    apricot('(. "foo" append "bar")').should == "foobar"
    apricot('(. "foo" (append "bar"))').should == "foobar"
  end

  it 'compiles send forms with block args' do
    apricot('(. [1 2 3] map | :to_s)').should == ['1', '2', '3']
    apricot('(. [1 2 3] (map | :to_s))').should == ['1', '2', '3']
    apricot('(. [1 2 3] map | #(. % + 1))').should == [2, 3, 4]
    apricot('(. [1 2 3] (map | #(. % + 1)))').should == [2, 3, 4]
  end

  it 'compiles shorthand send forms' do
    apricot('(.class 1)').should == Fixnum
    apricot('(.append "foo" "bar")').should == "foobar"
  end

  it 'compiles shorthand send forms with block args' do
    apricot('(.map [1 2 3] | :to_s)').should == ['1', '2', '3']
    apricot('(.map [1 2 3] | #(. % + 1))').should == [2, 3, 4]
  end

  it 'macroexpands shorthand send forms' do
    form = apricot "'(.meth recv arg1 arg2)"
    ex = Apricot.macroexpand(form)

    dot  = Identifier.intern(:'.')
    recv = Identifier.intern(:recv)
    meth = Identifier.intern(:meth)
    arg1 = Identifier.intern(:arg1)
    arg2 = Identifier.intern(:arg2)
    ex.should == List[dot, recv, meth, arg1, arg2]
  end

  it 'compiles shorthand new forms' do
    apricot('(Range. 1 10)').should == (1..10)
    apricot('(Array. 2 5)').should == [5, 5]
  end

  it 'compiles shorthand new forms with block args' do
    apricot('(Array. 3 | :to_s)').should == ["0", "1", "2"]
    apricot('(Array. 5 | #(* % %))').should == [0, 1, 4, 9, 16]
  end

  it 'macroexpands shorthand new forms' do
    form = apricot "'(Klass. arg1 arg2)"
    ex = Apricot.macroexpand(form)

    dot   = Identifier.intern(:'.')
    klass = Identifier.intern(:Klass)
    new   = Identifier.intern(:new)
    arg1  = Identifier.intern(:arg1)
    arg2  = Identifier.intern(:arg2)
    ex.should == List[dot, klass, new, arg1, arg2]
  end

  it 'compiles constant defs' do
    expect { Foo }.to raise_error(NameError)
    apricot '(def Foo 1)'
    Foo.should == 1
  end

  it 'compiles if forms' do
    apricot('(if true :foo :bar)').should == :foo
    apricot('(if false :foo :bar)').should == :bar
    apricot('(if true :foo)').should == :foo
    apricot('(if false :foo)').should == nil
  end

  it 'compiles do forms' do
    apricot('(do)').should == nil
    apricot('(do 1)').should == 1
    apricot('(do 1 2 3)').should == 3
    expect { Bar }.to raise_error(NameError)
    apricot('(do (def Bar 1) Bar)').should == 1
  end

  it 'compiles let forms' do
    apricot('(let [])').should == nil
    apricot('(let [a 1])').should == nil
    apricot('(let [a 1] a)').should == 1
    apricot('(let [a 1 b 2] [b a])').should == [2, 1]
    apricot('(let [a 1] [(let [a 2] a) a])').should == [2, 1]
    apricot('(let [a 1 b 2] (let [a 42] [b a]))').should == [2, 42]
    apricot('(let [a 1 b a] [a b])').should == [1, 1]
    apricot('(let [a 1] (let [b a] [a b]))').should == [1, 1]
  end

  it 'compiles fn forms' do
    apricot('((fn []))').should == nil
    apricot('((fn [] 42))').should == 42
    apricot('((fn [x] x) 42)').should == 42
    apricot('((fn [x y] [y x]) 1 2)').should == [2, 1]
  end

  it 'compiles fn forms with optional arguments' do
    apricot('((fn [[x 42]] x))').should == 42
    apricot('((fn [[x 42]] x) 0)').should == 0
    apricot('((fn [x [y 2]] [x y]) 1)').should == [1, 2]
    apricot('((fn [x [y 2]] [x y]) 3 4)').should == [3, 4]
    apricot('((fn [[x 1] [y 2]] [x y]))').should == [1, 2]
    apricot('((fn [[x 1] [y 2]] [x y]) 3)').should == [3, 2]
    apricot('((fn [[x 1] [y 2]] [x y]) 3 4)').should == [3, 4]
  end

  it 'compiles fn forms with splat arguments' do
    apricot('((fn [& x] x))').should == []
    apricot('((fn [& x] x) 1)').should == [1]
    apricot('((fn [& x] x) 1 2)').should == [1, 2]
    apricot('((fn [x & y] y) 1)').should == []
    apricot('((fn [x & y] y) 1 2 3)').should == [2, 3]
  end

  it 'compiles fn forms with optional and splat arguments' do
    apricot('((fn [x [y 2] & z] [x y z]) 1)').should == [1, 2, []]
    apricot('((fn [x [y 2] & z] [x y z]) 1 3)').should == [1, 3, []]
    apricot('((fn [x [y 2] & z] [x y z]) 1 3 4 5)').should == [1, 3, [4, 5]]
  end

  it 'compiles fn forms with block arguments' do
    apricot('((fn [| block] block))').should == nil
    apricot('(.call (fn [| block] (block)) | (fn [] 42))').should == 42

    fn = apricot '(fn [x | block] (block x))'
    # Without passing a block, 'block' is nil.
    expect { fn.call(2) }.to raise_error(NoMethodError)
    fn.call(2) {|x| x + 40 }.should == 42

    reduce_args = apricot <<-CODE
      (fn reduce-args
        ([x] x)
        ([x y | f] (f x y))
        ([x y & more | f]
         (recur (f x y) (first more) (next more))))
    CODE

    reduce_args.call(1).should == 1
    reduce_args.call(40, 2) {|x,y| x * y }.should == 80
    reduce_args.call(1,2,3,4,5,6) {|x,y| x + y }.should == 21
  end

  it 'does not compile invalid fn forms' do
    bad_apricot '(fn :foo)'
    bad_apricot '(fn [1])'
    bad_apricot '(fn [[x 1] y])'
    bad_apricot '(fn [[1 1]])'
    bad_apricot '(fn [[x]])'
    bad_apricot '(fn [&])'
    bad_apricot '(fn [& x y])'
    bad_apricot '(fn [x x])'
    bad_apricot '(fn [x & rest1 & rest2])'
    bad_apricot '(fn [a b x c d x e f])'
    bad_apricot '(fn [a x b [x 1]])'
    bad_apricot '(fn [a b x c d & x])'
    bad_apricot '(fn [a b c [x 1] [y 2] [x 3]])'
    bad_apricot '(fn [a b [x 1] & x])'
    bad_apricot '(fn [|])'
    bad_apricot '(fn [| &])'
    bad_apricot '(fn [| & a])'
    bad_apricot '(fn [| a &])'
    bad_apricot '(fn [& x |])'
    bad_apricot '(fn [| x y])'
    bad_apricot '(fn [| x & y])'
    bad_apricot '(fn [x | x])'
    bad_apricot '(fn [x | b1 | b2])'
  end

  it 'compiles arity-overloaded fn forms' do
    apricot('((fn ([] 0)))') == 0
    apricot('((fn ([x] x)) 42)') == 42
    apricot('((fn ([[x 42]] x)))') == 42
    apricot('((fn ([& rest] rest)) 1 2 3)') == [1, 2, 3]
    apricot('((fn ([] 0) ([x] x)))') == 0
    apricot('((fn ([] 0) ([x] x)) 42)') == 42
    apricot('((fn ([x] x) ([x y] y)) 42)') == 42
    apricot('((fn ([x] x) ([x y] y)) 42 13)') == 13

    add_fn = apricot <<-CODE
      (fn
        ([] 0)
        ([x] x)
        ([x y] (.+ x y))
        ([x y & more]
         (.reduce more (.+ x y) :+)))
    CODE

    add_fn.call.should == 0
    add_fn.call(42).should == 42
    add_fn.call(1,2).should == 3
    add_fn.call(1,2,3).should == 6
    add_fn.call(1,2,3,4,5,6,7,8).should == 36

    two_or_three = apricot '(fn ([x y] 2) ([x y z] 3))'
    expect { two_or_three.call }.to raise_error(ArgumentError)
    expect { two_or_three.call(1) }.to raise_error(ArgumentError)
    two_or_three.call(1,2).should == 2
    two_or_three.call(1,2,3).should == 3
    expect { two_or_three.call(1,2,3,4) }.to raise_error(ArgumentError)
    expect { two_or_three.call(1,2,3,4,5) }.to raise_error(ArgumentError)
  end

  it 'compiles arity-overloaded fns with no matching overloads for some arities' do
    zero_or_two = apricot '(fn ([] 0) ([x y] 2))'
    zero_or_two.call.should == 0
    expect { zero_or_two.call(1) }.to raise_error(ArgumentError)
    zero_or_two.call(1,2).should == 2
    expect { zero_or_two.call(1,2,3) }.to raise_error(ArgumentError)

    one_or_four = apricot '(fn ([w] 1) ([w x y z] 4))'
    expect { one_or_four.call }.to raise_error(ArgumentError)
    one_or_four.call(1).should == 1
    expect { one_or_four.call(1,2) }.to raise_error(ArgumentError)
    expect { one_or_four.call(1,2,3) }.to raise_error(ArgumentError)
    one_or_four.call(1,2,3,4).should == 4
    expect { one_or_four.call(1,2,3,4,5) }.to raise_error(ArgumentError)
  end

  it 'does not compile invalid arity-overloaded fn forms' do
    bad_apricot '(fn ([] 1) :foo)'
    bad_apricot '(fn ([] 1) ([] 2))'
    bad_apricot '(fn ([[o 1]] 1) ([] 2))'
    bad_apricot '(fn ([] 1) ([[o 2]] 2))'
    bad_apricot '(fn ([[o 1]] 1) ([[o 2]] 2))'
    bad_apricot '(fn ([x [o 1]] 1) ([x] 2))'
    bad_apricot '(fn ([x [o 1]] 1) ([[o 2]] 2))'
    bad_apricot '(fn ([x y z [o 1]] 1) ([x y z & rest] 2))'
    bad_apricot '(fn ([x [o 1] [p 2] [q 3]] 1) ([x y z] 2))'
    bad_apricot '(fn ([x & rest] 1) ([x y] 2))'
    bad_apricot '(fn ([x & rest] 1) ([x [o 1]] 2))'
    bad_apricot '(fn ([x [o 1] & rest] 1) ([x] 2))'
  end

  it 'compiles fn forms with self-reference' do
    foo = apricot '(fn foo [] foo)'
    foo.call.should == foo

    # This one will stack overflow from the infinite loop.
    expect { apricot '((fn foo [] (foo)))' }.to raise_error(SystemStackError)

    add = apricot <<-CODE
      (fn add
        ([] 0)
        ([& args]
         (.+ (first args) (apply add (rest args)))))
    CODE

    add.call.should == 0
    add.call(1).should == 1
    add.call(1,2,3).should == 6
  end

  it 'compiles loop and recur forms' do
    apricot('(loop [])').should == nil
    apricot('(loop [a 1])').should == nil
    apricot('(loop [a 1] a)').should == 1

    apricot(<<-CODE).should == [5,4,3,2,1]
      (let [a []]
        (loop [x 5]
          (if (. x > 0)
            (do
              (. a << x)
              (recur (. x - 1)))))
        a)
    CODE
  end

  it 'compiles recur forms in fns' do
    apricot(<<-CODE).should == 15
      ((fn [x y]
         (if (. x > 0)
           (recur (. x - 1) (. y + x))
           y))
       5 0)
    CODE
  end

  it 'compiles recur forms in fns with optional arguments' do
    apricot(<<-CODE).should == 150
      ((fn [x y [mult 10]]
         (if (. x > 0)
           (recur (. x - 1) (. y + x) mult)
           (* y mult)))
       5 0)
    CODE

    apricot(<<-CODE).should == 300
      ((fn [x y [mult 10]]
         (if (. x > 0)
           (recur (. x - 1) (. y + x) mult)
           (* y mult)))
       5 0 20)
    CODE
  end

  it 'does not compile invalid recur forms' do
    bad_apricot '(fn [] (recur 1))'
    bad_apricot '(fn [x] (recur))'
    bad_apricot '(fn [[x 10]] (recur))'
    bad_apricot '(fn [x & rest] (recur 1))'
    bad_apricot '(fn [x & rest] (recur 1 2 3))'
  end

  it 'compiles recur forms in arity-overloaded fns' do
    apricot(<<-CODE).should == 0
      ((fn
         ([] 0)
         ([& args] (recur [])))
        1 2 3)
    CODE

    apricot(<<-CODE).should == 0
      ((fn
         ([] 0)
         ([& args] (recur (rest args))))
        1 2 3)
    CODE

    apricot(<<-CODE).should == 6
      ((fn
         ([x] x)
         ([x & args] (recur (.+ x (first args)) (rest args))))
        1 2 3)
    CODE

    apricot(<<-CODE).should == 42
      ((fn
         ([] 0)
         ([x y & args]
          (if (.empty? args)
            42
            (recur x y (rest args)))))
        1 2 3)
    CODE
  end

  it 'compiles try forms' do
    apricot('(try)').should == nil
    apricot('(try :foo)').should == :foo

    apricot('(try :success (rescue e :rescue))').should == :success
    expect { apricot '(try (. Kernel raise))' }.to raise_error(RuntimeError)
    apricot('(try (. Kernel raise) (rescue e :rescue))').should == :rescue
    apricot('(try (. Kernel raise) (rescue [e] :rescue))').should == :rescue
    apricot(<<-CODE).should == :rescue
      (try
        (. Kernel raise)
        (rescue [e 1 2 RuntimeError] :rescue))
    CODE
    apricot(<<-CODE).should == :rescue_bar
      (try
        (. Kernel raise ArgumentError)
        (rescue [e TypeError] :rescue_foo)
        (rescue [e ArgumentError] :rescue_bar))
    CODE
    apricot(<<-CODE).should be_a(TypeError)
      (try
        (. Kernel raise TypeError)
        (rescue e e))
    CODE
    expect { apricot(<<-CODE) }.to raise_error(TypeError)
      (try
        (. Kernel raise TypeError)
        (rescue [e ArgumentError] :rescue))
    CODE

    apricot(<<-CODE).should == :rescue
      (try
        (try
          (. Kernel raise)
          (rescue e (. Kernel raise)))
        (rescue e :rescue))
    CODE

    apricot(<<-CODE).should == []
      (let [a [1]]
        (try
          :success
          (ensure (.pop a)))
        a)
    CODE
    apricot(<<-CODE).should == []
      (let [a [1]]
        (try
          (. Kernel raise)
          (rescue e :rescue)
          (ensure (.pop a)))
        a)
    CODE
    apricot(<<-CODE).should == []
      (let [a [1]]
        (try
          (try
            (. Kernel raise)
            (ensure (.pop a)))
          (rescue e :rescue))
        a)
    CODE
  end

  it 'compiles quoted forms' do
    apricot("'1").should == 1
    apricot("'a").should == Identifier.intern(:a)
    apricot("''a").should == List[
      Identifier.intern(:quote),
      Identifier.intern(:a)
    ]
    apricot("'1.2").should == 1.2
    apricot("'1/2").should == Rational(1,2)
    apricot("':a").should == :a
    apricot("'()").should == List::EmptyList
    apricot("'(1)").should == List[1]
    apricot("'[a]").should == [Identifier.intern(:a)]
    apricot("'{a 1}").should == {Identifier.intern(:a) => 1}
    apricot('\'"foo"').should == "foo"
    apricot("'true").should == true
    apricot("'false").should == false
    apricot("'nil").should == nil
    apricot("'self").should == Identifier.intern(:self)
    apricot("'Foo::Bar").should == Identifier.intern(:'Foo::Bar')
  end
end
