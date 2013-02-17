describe 'Apricot' do
  def apricot(code)
    Apricot::Compiler.eval code
  end

  def bad_apricot(code)
    expect { apricot(code) }.to raise_error(CompileError)
  end

  it 'compiles an empty program' do
    apricot(%q||).should == nil
  end

  it 'compiles false, true and nil' do
    apricot(%q|true|).should == true
    apricot(%q|false|).should == false
    apricot(%q|nil|).should == nil
  end

  it 'compiles numbers' do
    apricot(%q|1|).should == 1
    apricot(%q|1.0|).should == 1.0
    apricot(%q|1/3|).should == Rational(1, 3)
  end

  it 'compiles symbols' do
    apricot(%q|:foo|).should == :foo
  end

  it 'compiles strings' do
    apricot(%q|"foo"|).should == "foo"
  end

  it 'compiles regexes' do
    apricot(%q|#r"foo"|).should == /foo/
    apricot(%q|#r/foo/x|).should == /foo/x
    apricot(%q|#r[foo]xim|).should == /foo/xim
  end

  it 'compiles arrays' do
    apricot(%q|[]|).should == []
    apricot(%q|[1 2 3]|).should == [1, 2, 3]
  end

  it 'compiles hashes' do
    apricot(%q|{}|).should == {}
    apricot(%q|{:foo 1, :bar 2}|).should == {:foo => 1, :bar => 2}
  end

  it 'compiles sets' do
    apricot(%q|#{}|).should == Set.new
    apricot(%q|#{:foo :foo :bar}|).should == Set[:foo, :foo, :bar]
  end

  it 'compiles constants' do
    apricot(%q|Array|).should == Array
    apricot(%q|Rubinius::Compiler|).should == Rubinius::Compiler
  end

  it 'compiles call forms with data structures' do
    apricot(%q|([:a :b] 1)|).should == :b
    apricot(%q|([:a :b] 3)|).should == nil
    apricot(%q|(#{:a :b} :b)|).should == :b
    apricot(%q|(#{:a :b} :c)|).should == nil
    apricot(%q|({:a 1} :a)|).should == 1
    apricot(%q|({:a 1} :b)|).should == nil
  end

  it 'compiles symbol call forms' do
    apricot(%q|(:a {:a 1 :b 2})|).should == 1
    apricot(%q|(:c {:a 1 :b 2})|).should == nil
    apricot(%q|(:a #{:a :b})|).should == :a
    apricot(%q|(:c #{:a :b})|).should == nil
  end

  it 'compiles send forms' do
    apricot(%q|(. 1 class)|).should == Fixnum
    apricot(%q|(. 1 (class))|).should == Fixnum
    apricot(%q|(. "foo" append "bar")|).should == "foobar"
    apricot(%q|(. "foo" (append "bar"))|).should == "foobar"
  end

  it 'compiles send forms with block args' do
    apricot(%q|(. [1 2 3] map \| :to_s)|).should == %w[1 2 3]
    apricot(%q|(. [1 2 3] (map \| :to_s))|).should == %w[1 2 3]
    apricot(%q|(. [1 2 3] map \| #(. % + 1))|).should == [2, 3, 4]
    apricot(%q|(. [1 2 3] (map \| #(. % + 1)))|).should == [2, 3, 4]
  end

  it 'compiles shorthand send forms' do
    apricot(%q|(.class 1)|).should == Fixnum
    apricot(%q|(.append "foo" "bar")|).should == "foobar"
  end

  it 'compiles shorthand send forms with block args' do
    apricot(%q|(.map [1 2 3] \| :to_s)|).should == %w[1 2 3]
    apricot(%q|(.map [1 2 3] \| #(. % + 1))|).should == [2, 3, 4]
  end

  it 'macroexpands shorthand send forms' do
    form = apricot(%q|'(.meth recv arg1 arg2)|)
    ex = Apricot.macroexpand(form)

    dot  = Identifier.intern(:'.')
    recv = Identifier.intern(:recv)
    meth = Identifier.intern(:meth)
    arg1 = Identifier.intern(:arg1)
    arg2 = Identifier.intern(:arg2)
    ex.should == List[dot, recv, meth, arg1, arg2]
  end

  it 'compiles shorthand new forms' do
    apricot(%q|(Range. 1 10)|).should == (1..10)
    apricot(%q|(Array. 2 5)|).should == [5, 5]
  end

  it 'compiles shorthand new forms with block args' do
    apricot(%q|(Array. 3 \| :to_s)|).should == ["0", "1", "2"]
    apricot(%q|(Array. 5 \| #(* % %))|).should == [0, 1, 4, 9, 16]
  end

  it 'macroexpands shorthand new forms' do
    form = apricot(%q|'(Klass. arg1 arg2)|)
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
    apricot(%q|(def Foo 1)|)
    Foo.should == 1
  end

  it 'compiles if forms' do
    apricot(%q|(if true :foo :bar)|).should == :foo
    apricot(%q|(if false :foo :bar)|).should == :bar
    apricot(%q|(if true :foo)|).should == :foo
    apricot(%q|(if false :foo)|).should == nil
  end

  it 'compiles do forms' do
    apricot(%q|(do)|).should == nil
    apricot(%q|(do 1)|).should == 1
    apricot(%q|(do 1 2 3)|).should == 3
    expect { Bar }.to raise_error(NameError)
    apricot(%q|(do (def Bar 1) Bar)|).should == 1
  end

  it 'compiles let forms' do
    apricot(%q|(let [])|).should == nil
    apricot(%q|(let [a 1])|).should == nil
    apricot(%q|(let [a 1] a)|).should == 1
    apricot(%q|(let [a 1 b 2] [b a])|).should == [2, 1]
    apricot(%q|(let [a 1] [(let [a 2] a) a])|).should == [2, 1]
    apricot(%q|(let [a 1 b 2] (let [a 42] [b a]))|).should == [2, 42]
    apricot(%q|(let [a 1 b a] [a b])|).should == [1, 1]
    apricot(%q|(let [a 1] (let [b a] [a b]))|).should == [1, 1]
  end

  it 'compiles fn forms' do
    apricot(%q|((fn []))|).should == nil
    apricot(%q|((fn [] 42))|).should == 42
    apricot(%q|((fn [x] x) 42)|).should == 42
    apricot(%q|((fn [x y] [y x]) 1 2)|).should == [2, 1]
  end

  it 'compiles fn forms with optional arguments' do
    apricot(%q|((fn [[x 42]] x))|).should == 42
    apricot(%q|((fn [[x 42]] x) 0)|).should == 0
    apricot(%q|((fn [x [y 2]] [x y]) 1)|).should == [1, 2]
    apricot(%q|((fn [x [y 2]] [x y]) 3 4)|).should == [3, 4]
    apricot(%q|((fn [[x 1] [y 2]] [x y]))|).should == [1, 2]
    apricot(%q|((fn [[x 1] [y 2]] [x y]) 3)|).should == [3, 2]
    apricot(%q|((fn [[x 1] [y 2]] [x y]) 3 4)|).should == [3, 4]
  end

  it 'compiles fn forms with splat arguments' do
    apricot(%q|((fn [& x] x))|).should == []
    apricot(%q|((fn [& x] x) 1)|).should == [1]
    apricot(%q|((fn [& x] x) 1 2)|).should == [1, 2]
    apricot(%q|((fn [x & y] y) 1)|).should == []
    apricot(%q|((fn [x & y] y) 1 2 3)|).should == [2, 3]
  end

  it 'compiles fn forms with optional and splat arguments' do
    apricot(%q|((fn [x [y 2] & z] [x y z]) 1)|).should == [1, 2, []]
    apricot(%q|((fn [x [y 2] & z] [x y z]) 1 3)|).should == [1, 3, []]
    apricot(%q|((fn [x [y 2] & z] [x y z]) 1 3 4 5)|).should == [1, 3, [4, 5]]
  end

  it 'does not compile invalid fn forms' do
    bad_apricot(%q|(fn :foo)|)
    bad_apricot(%q|(fn [1])|)
    bad_apricot(%q|(fn [[x 1] y])|)
    bad_apricot(%q|(fn [[1 1]])|)
    bad_apricot(%q|(fn [[x]])|)
    bad_apricot(%q|(fn [&])|)
    bad_apricot(%q|(fn [& x y])|)
    bad_apricot(%q|(fn [x x])|)
    bad_apricot(%q|(fn [a b x c d x e f])|)
    bad_apricot(%q|(fn [a x b [x 1]])|)
    bad_apricot(%q|(fn [a b x c d & x])|)
    bad_apricot(%q|(fn [a b c [x 1] [y 2] [x 3]])|)
    bad_apricot(%q|(fn [a b [x 1] & x])|)
  end

  it 'compiles arity-overloaded fn forms' do
    apricot(%q|((fn ([] 0)))|) == 0
    apricot(%q|((fn ([x] x)) 42)|) == 42
    apricot(%q|((fn ([[x 42]] x)))|) == 42
    apricot(%q|((fn ([& rest] rest)) 1 2 3)|) == [1, 2, 3]
    apricot(%q|((fn ([] 0) ([x] x)))|) == 0
    apricot(%q|((fn ([] 0) ([x] x)) 42)|) == 42
    apricot(%q|((fn ([x] x) ([x y] y)) 42)|) == 42
    apricot(%q|((fn ([x] x) ([x y] y)) 42 13)|) == 13

    add_fn = apricot(<<-END)
      (fn
        ([] 0)
        ([x] x)
        ([x y] (.+ x y))
        ([x y & more]
         (.reduce more (.+ x y) :+)))
    END

    add_fn.call.should == 0
    add_fn.call(42).should == 42
    add_fn.call(1,2).should == 3
    add_fn.call(1,2,3).should == 6
    add_fn.call(1,2,3,4,5,6,7,8).should == 36

    two_or_three = apricot(%q|(fn ([x y] 2) ([x y z] 3))|)
    expect { two_or_three.call }.to raise_error(ArgumentError)
    expect { two_or_three.call(1) }.to raise_error(ArgumentError)
    two_or_three.call(1,2).should == 2
    two_or_three.call(1,2,3).should == 3
    expect { two_or_three.call(1,2,3,4) }.to raise_error(ArgumentError)
    expect { two_or_three.call(1,2,3,4,5) }.to raise_error(ArgumentError)
  end

  it 'compiles arity-overloaded fns with no matching overloads for some arities' do
    zero_or_two = apricot(%q|(fn ([] 0) ([x y] 2))|)
    zero_or_two.call.should == 0
    expect { zero_or_two.call(1) }.to raise_error(ArgumentError)
    zero_or_two.call(1,2).should == 2
    expect { zero_or_two.call(1,2,3) }.to raise_error(ArgumentError)

    one_or_four = apricot(%q|(fn ([w] 1) ([w x y z] 4))|)
    expect { one_or_four.call }.to raise_error(ArgumentError)
    one_or_four.call(1).should == 1
    expect { one_or_four.call(1,2) }.to raise_error(ArgumentError)
    expect { one_or_four.call(1,2,3) }.to raise_error(ArgumentError)
    one_or_four.call(1,2,3,4).should == 4
    expect { one_or_four.call(1,2,3,4,5) }.to raise_error(ArgumentError)
  end

  it 'does not compile invalid arity-overloaded fn forms' do
    bad_apricot(%q|(fn ([] 1) :foo)|)
    bad_apricot(%q|(fn ([] 1) ([] 2))|)
    bad_apricot(%q|(fn ([[o 1]] 1) ([] 2))|)
    bad_apricot(%q|(fn ([] 1) ([[o 2]] 2))|)
    bad_apricot(%q|(fn ([[o 1]] 1) ([[o 2]] 2))|)
    bad_apricot(%q|(fn ([x [o 1]] 1) ([x] 2))|)
    bad_apricot(%q|(fn ([x [o 1]] 1) ([[o 2]] 2))|)
    bad_apricot(%q|(fn ([x y z [o 1]] 1) ([x y z & rest] 2))|)
    bad_apricot(%q|(fn ([x [o 1] [p 2] [q 3]] 1) ([x y z] 2))|)
    bad_apricot(%q|(fn ([x & rest] 1) ([x y] 2))|)
    bad_apricot(%q|(fn ([x & rest] 1) ([x [o 1]] 2))|)
    bad_apricot(%q|(fn ([x [o 1] & rest] 1) ([x] 2))|)
  end

  it 'compiles loop and recur forms' do
    apricot(%q|(loop [])|).should == nil
    apricot(%q|(loop [a 1])|).should == nil
    apricot(%q|(loop [a 1] a)|).should == 1

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
    bad_apricot(%q|(fn [] (recur 1))|)
    bad_apricot(%q|(fn [x] (recur))|)
    bad_apricot(%q|(fn [[x 10]] (recur))|)
    bad_apricot(%q|(fn [x & rest] (recur 1))|)
    bad_apricot(%q|(fn [x & rest] (recur 1 2 3))|)
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
    apricot(%q|(try)|).should == nil
    apricot(%q|(try :foo)|).should == :foo

    apricot(%q|(try :success (rescue e :rescue))|).should == :success
    expect { apricot(%q|(try (. Kernel raise))|) }.to raise_error(RuntimeError)
    apricot(%q|(try (. Kernel raise) (rescue e :rescue))|).should == :rescue
    apricot(%q|(try (. Kernel raise) (rescue [e] :rescue))|).should == :rescue
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
    apricot(%q|'1|).should == 1
    apricot(%q|'a|).should == Identifier.intern(:a)
    apricot(%q|''a|).should == List[
      Identifier.intern(:quote),
      Identifier.intern(:a)
    ]
    apricot(%q|'1.2|).should == 1.2
    apricot(%q|'1/2|).should == Rational(1,2)
    apricot(%q|':a|).should == :a
    apricot(%q|'()|).should == List::EmptyList
    apricot(%q|'(1)|).should == List[1]
    apricot(%q|'[a]|).should == [Identifier.intern(:a)]
    apricot(%q|'{a 1}|).should == {Identifier.intern(:a) => 1}
    apricot(%q|'"foo"|).should == "foo"
    apricot(%q|'true|).should == true
    apricot(%q|'false|).should == false
    apricot(%q|'nil|).should == nil
    apricot(%q|'self|).should == Identifier.intern(:self)
    apricot(%q|'Foo::Bar|).should == Identifier.intern(:'Foo::Bar')
  end
end
