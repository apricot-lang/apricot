describe Apricot::Constant do
  def new_const(*names)
    described_class.new *names
  end

  it 'responds to the #name method' do
    new_const(:Foo, :Bar, :Baz).name.should == 'Foo::Bar::Baz'
  end

  it 'supports the == operator' do
    c1 = new_const :A, :B
    c2 = new_const :A, :B
    c3 = new_const :A

    c1.should == c2
    c2.should == c1

    c1.should_not == c3
    c3.should_not == c1

    c1.should_not == 42
  end

  it 'can be inspected' do
    new_const(:A, :B).inspect.should == '#<Apricot::Constant A::B>'
  end

  it 'can be used as a key in Hashes' do
    c1 = new_const :A, :B
    c2 = new_const :A, :B
    c3 = new_const :A
    h = {}

    h[c1] = 1
    h[c2] = 2
    h[c3] = 3

    h[c1].should == 2
    h[c2].should == 2
    h[c3].should == 3
  end
end
