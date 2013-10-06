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
    apr('Enumerable::Enumerator').should == Enumerable::Enumerator
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

  it 'compiles constant defs' do
    expect { Foo }.to raise_error(NameError)
    apr '(def Foo 1)'
    Foo.should == 1
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
