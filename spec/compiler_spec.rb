describe 'Apricot' do
  include CompilerSpec

  it 'compiles an empty program' do
    apr('').should == nil
  end

  it 'compiles false, true and nil' do
    apr('true').should == true
    apr('false').should == false
    apr('nil').should == nil
  end

  it 'compiles numbers' do
    apr('1').should == 1
    apr('1.0').should == 1.0
    apr('1/3').should == Rational(1, 3)
  end

  it 'compiles symbols' do
    apr(':foo').should == :foo
  end

  it "doesn't mix up symbols and keywords in lists" do
    # There once was a bug where :true would get compiled as the value true.
    apr('(.class :true)').should == Symbol
  end

  it 'compiles strings' do
    apr('"foo"').should == "foo"
  end

  it 'compiles regexes' do
    apr('#r"foo"').should == /foo/
    apr('#r/foo/x').should == /foo/x
    apr('#r[foo]xim').should == /foo/xim
  end

  it 'compiles arrays' do
    apr('[]').should == []
    apr('[1 2 3]').should == [1, 2, 3]
  end

  it 'compiles hashes' do
    apr('{}').should == {}
    apr('{:foo 1, :bar 2}').should == {:foo => 1, :bar => 2}
  end

  it 'compiles sets' do
    apr('#{}').should == Set.new
    apr('#{:foo :foo :bar}').should == Set[:foo, :foo, :bar]
  end

  it 'compiles constants' do
    apr('Array').should == Array
    apr('Rubinius::Compiler').should == Rubinius::Compiler
  end

  it 'compiles call forms with data structures' do
    apr('([:a :b] 1)').should == :b
    apr('([:a :b] 3)').should == nil
    apr('(#{:a :b} :b)').should == :b
    apr('(#{:a :b} :c)').should == nil
    apr('({:a 1} :a)').should == 1
    apr('({:a 1} :b)').should == nil
  end

  it 'compiles symbol call forms' do
    apr('(:a {:a 1 :b 2})').should == 1
    apr('(:c {:a 1 :b 2})').should == nil
    apr('(:a #{:a :b})').should == :a
    apr('(:c #{:a :b})').should == nil
  end

  it 'compiles shorthand send forms' do
    apr('(.class 1)').should == Fixnum
    apr('(.append "foo" "bar")').should == "foobar"
  end

  it 'compiles shorthand send forms with block args' do
    apr('(.map [1 2 3] | :to_s)').should == ['1', '2', '3']
    apr('(.map [1 2 3] | #(. % + 1))').should == [2, 3, 4]
  end

  it 'macroexpands shorthand send forms' do
    form = apr "'(.meth recv arg1 arg2)"
    ex = Apricot.macroexpand(form)

    dot  = Identifier.intern(:'.')
    recv = Identifier.intern(:recv)
    meth = Identifier.intern(:meth)
    arg1 = Identifier.intern(:arg1)
    arg2 = Identifier.intern(:arg2)
    ex.should == List[dot, recv, meth, arg1, arg2]
  end

  it 'compiles shorthand new forms' do
    apr('(Range. 1 10)').should == (1..10)
    apr('(Array. 2 5)').should == [5, 5]
  end

  it 'compiles shorthand new forms with block args' do
    apr('(Array. 3 | :to_s)').should == ["0", "1", "2"]
    apr('(Array. 5 | #(* % %))').should == [0, 1, 4, 9, 16]
  end

  it 'macroexpands shorthand new forms' do
    form = apr "'(Klass. arg1 arg2)"
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
    apr '(def Foo 1)'
    Foo.should == 1
  end

  it 'compiles fn forms' do
    apr('((fn []))').should == nil
    apr('((fn [] 42))').should == 42
    apr('((fn [x] x) 42)').should == 42
    apr('((fn [x y] [y x]) 1 2)').should == [2, 1]
  end

  it 'compiles fn forms with optional arguments' do
    apr('((fn [[x 42]] x))').should == 42
    apr('((fn [[x 42]] x) 0)').should == 0
    apr('((fn [x [y 2]] [x y]) 1)').should == [1, 2]
    apr('((fn [x [y 2]] [x y]) 3 4)').should == [3, 4]
    apr('((fn [[x 1] [y 2]] [x y]))').should == [1, 2]
    apr('((fn [[x 1] [y 2]] [x y]) 3)').should == [3, 2]
    apr('((fn [[x 1] [y 2]] [x y]) 3 4)').should == [3, 4]
  end

  it 'compiles fn forms with splat arguments' do
    apr('((fn [& x] x))').should == []
    apr('((fn [& x] x) 1)').should == [1]
    apr('((fn [& x] x) 1 2)').should == [1, 2]
    apr('((fn [x & y] y) 1)').should == []
    apr('((fn [x & y] y) 1 2 3)').should == [2, 3]
  end

  it 'compiles fn forms with optional and splat arguments' do
    apr('((fn [x [y 2] & z] [x y z]) 1)').should == [1, 2, []]
    apr('((fn [x [y 2] & z] [x y z]) 1 3)').should == [1, 3, []]
    apr('((fn [x [y 2] & z] [x y z]) 1 3 4 5)').should == [1, 3, [4, 5]]
  end

  it 'compiles fn forms with block arguments' do
    apr('((fn [| block] block))').should == nil
    apr('(.call (fn [| block] (block)) | (fn [] 42))').should == 42

    fn = apr '(fn [x | block] (block x))'
    # Without passing a block, 'block' is nil.
    expect { fn.call(2) }.to raise_error(NoMethodError)
    fn.call(2) {|x| x + 40 }.should == 42

    reduce_args = apr <<-CODE
      (fn reduce-args
        ([x] x)
        ([x y | f] (f x y))
        ([x y & more | f]
         (if (seq more)
           (recur (f x y) (first more) (next more) f)
           (f x y))))
    CODE

    reduce_args.call(1).should == 1
    reduce_args.call(40, 2) {|x,y| x * y }.should == 80
    reduce_args.call(1,2,3,4,5,6) {|x,y| x + y }.should == 21
  end

  it 'does not compile invalid fn forms' do
    bad_apr '(fn :foo)'
    bad_apr '(fn [1])'
    bad_apr '(fn [[x 1] y])'
    bad_apr '(fn [[1 1]])'
    bad_apr '(fn [[x]])'
    bad_apr '(fn [&])'
    bad_apr '(fn [& x y])'
    bad_apr '(fn [x x])'
    bad_apr '(fn [x & rest1 & rest2])'
    bad_apr '(fn [a b x c d x e f])'
    bad_apr '(fn [a x b [x 1]])'
    bad_apr '(fn [a b x c d & x])'
    bad_apr '(fn [a b c [x 1] [y 2] [x 3]])'
    bad_apr '(fn [a b [x 1] & x])'
    bad_apr '(fn [|])'
    bad_apr '(fn [| &])'
    bad_apr '(fn [| & a])'
    bad_apr '(fn [| a &])'
    bad_apr '(fn [& x |])'
    bad_apr '(fn [| x y])'
    bad_apr '(fn [| x & y])'
    bad_apr '(fn [x | x])'
    bad_apr '(fn [x | b1 | b2])'
  end

  it 'compiles arity-overloaded fn forms' do
    apr('((fn ([] 0)))') == 0
    apr('((fn ([x] x)) 42)') == 42
    apr('((fn ([[x 42]] x)))') == 42
    apr('((fn ([& rest] rest)) 1 2 3)') == [1, 2, 3]
    apr('((fn ([] 0) ([x] x)))') == 0
    apr('((fn ([] 0) ([x] x)) 42)') == 42
    apr('((fn ([x] x) ([x y] y)) 42)') == 42
    apr('((fn ([x] x) ([x y] y)) 42 13)') == 13

    add_fn = apr <<-CODE
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

    two_or_three = apr '(fn ([x y] 2) ([x y z] 3))'
    expect { two_or_three.call }.to raise_error(ArgumentError)
    expect { two_or_three.call(1) }.to raise_error(ArgumentError)
    two_or_three.call(1,2).should == 2
    two_or_three.call(1,2,3).should == 3
    expect { two_or_three.call(1,2,3,4) }.to raise_error(ArgumentError)
    expect { two_or_three.call(1,2,3,4,5) }.to raise_error(ArgumentError)
  end

  it 'compiles arity-overloaded fns with no matching overloads for some arities' do
    zero_or_two = apr '(fn ([] 0) ([x y] 2))'
    zero_or_two.call.should == 0
    expect { zero_or_two.call(1) }.to raise_error(ArgumentError)
    zero_or_two.call(1,2).should == 2
    expect { zero_or_two.call(1,2,3) }.to raise_error(ArgumentError)

    one_or_four = apr '(fn ([w] 1) ([w x y z] 4))'
    expect { one_or_four.call }.to raise_error(ArgumentError)
    one_or_four.call(1).should == 1
    expect { one_or_four.call(1,2) }.to raise_error(ArgumentError)
    expect { one_or_four.call(1,2,3) }.to raise_error(ArgumentError)
    one_or_four.call(1,2,3,4).should == 4
    expect { one_or_four.call(1,2,3,4,5) }.to raise_error(ArgumentError)
  end

  it 'does not compile invalid arity-overloaded fn forms' do
    bad_apr '(fn ([] 1) :foo)'
    bad_apr '(fn ([] 1) ([] 2))'
    bad_apr '(fn ([[o 1]] 1) ([] 2))'
    bad_apr '(fn ([] 1) ([[o 2]] 2))'
    bad_apr '(fn ([[o 1]] 1) ([[o 2]] 2))'
    bad_apr '(fn ([x [o 1]] 1) ([x] 2))'
    bad_apr '(fn ([x [o 1]] 1) ([[o 2]] 2))'
    bad_apr '(fn ([x y z [o 1]] 1) ([x y z & rest] 2))'
    bad_apr '(fn ([x [o 1] [p 2] [q 3]] 1) ([x y z] 2))'
    bad_apr '(fn ([x & rest] 1) ([x y] 2))'
    bad_apr '(fn ([x & rest] 1) ([x [o 1]] 2))'
    bad_apr '(fn ([x [o 1] & rest] 1) ([x] 2))'
  end

  it 'compiles fn forms with self-reference' do
    foo = apr '(fn foo [] foo)'
    foo.call.should == foo

    # This one will stack overflow from the infinite loop.
    expect { apr '((fn foo [] (foo)))' }.to raise_error(SystemStackError)

    add = apr <<-CODE
      (fn add
        ([] 0)
        ([& args]
         (.+ (first args) (apply add (rest args)))))
    CODE

    add.call.should == 0
    add.call(1).should == 1
    add.call(1,2,3).should == 6
  end

  it 'compiles recur forms in fns' do
    apr(<<-CODE).should == 15
      ((fn [x y]
         (if (. x > 0)
           (recur (. x - 1) (. y + x))
           y))
       5 0)
    CODE
  end

  it 'compiles recur forms in fns with optional arguments' do
    apr(<<-CODE).should == 150
      ((fn [x y [mult 10]]
         (if (. x > 0)
           (recur (. x - 1) (. y + x) mult)
           (* y mult)))
       5 0)
    CODE

    apr(<<-CODE).should == 300
      ((fn [x y [mult 10]]
         (if (. x > 0)
           (recur (. x - 1) (. y + x) mult)
           (* y mult)))
       5 0 20)
    CODE
  end

  it 'compiles quoted forms' do
    apr("'1").should == 1
    apr("'a").should == Identifier.intern(:a)
    apr("''a").should == List[
      Identifier.intern(:quote),
      Identifier.intern(:a)
    ]
    apr("'1.2").should == 1.2
    apr("'1/2").should == Rational(1,2)
    apr("':a").should == :a
    apr("'()").should == List::EMPTY_LIST
    apr("'(1)").should == List[1]
    apr("'[a]").should == [Identifier.intern(:a)]
    apr("'{a 1}").should == {Identifier.intern(:a) => 1}
    apr('\'"foo"').should == "foo"
    apr("'true").should == true
    apr("'false").should == false
    apr("'nil").should == nil
    apr("'self").should == Identifier.intern(:self)
    apr("'Foo::Bar").should == Identifier.intern(:'Foo::Bar')
  end
end
