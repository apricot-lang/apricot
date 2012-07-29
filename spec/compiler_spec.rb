describe 'Apricot' do
  def apricot(code)
    Apricot::Compiler.eval code
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
    apricot(%q|'a|).should == Apricot::Identifier.intern(:a)
    apricot(%q|''a|).should == Apricot::List[
      Apricot::Identifier.intern(:quote),
      Apricot::Identifier.intern(:a)
    ]
    apricot(%q|'1.2|).should == 1.2
    apricot(%q|'1/2|).should == Rational(1,2)
    apricot(%q|':a|).should == :a
    apricot(%q|'()|).should == Apricot::List::EmptyList
    apricot(%q|'(1)|).should == Apricot::List[1]
    apricot(%q|'[a]|).should == [Apricot::Identifier.intern(:a)]
    apricot(%q|'{a 1}|).should == {Apricot::Identifier.intern(:a) => 1}
    apricot(%q|'"foo"|).should == "foo"
    apricot(%q|'true|).should == true
    apricot(%q|'false|).should == false
    apricot(%q|'nil|).should == nil
    apricot(%q|'Foo::Bar|).should == Apricot::Constant.new(:Foo, :Bar)
  end
end
