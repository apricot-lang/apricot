describe Apricot::Identifier do
  def intern(name)
    described_class.intern name
  end

  it 'does not support .new' do
    expect { described_class.new :foo }.to raise_error(NoMethodError)
  end

  it 'creates only one identifier for each name' do
    id1 = intern :foo
    id2 = intern :foo

    id1.object_id.should == id2.object_id
  end

  it 'supports the == operator' do
    id1 = intern :id1
    id2 = intern :id1
    id3 = intern :id3

    id1.should == id2
    id2.should == id1

    id1.should_not == id3
    id3.should_not == id1

    id1.should_not == 42
  end

  it 'can be inspected' do
    intern(:test).inspect.should == "test"
    intern(:true).inspect.should == "#|true|"
    intern(:false).inspect.should == "#|false|"
    intern(:nil).inspect.should == "#|nil|"
    intern(:"foo bar").inspect.should == "#|foo bar|"
    intern(:"foo | bar").inspect.should == '#|foo \| bar|'
    intern(:"foo\nbar").inspect.should == '#|foo\nbar|'
    intern(:"test\n").inspect.should == '#|test\n|'
  end

  it 'can be used as a key in Hashes' do
    id1 = intern :id1
    id2 = intern :id1
    id3 = intern :id3
    h = {}

    h[id1] = 1
    h[id2] = 2
    h[id3] = 3

    h[id1].should == 2
    h[id2].should == 2
    h[id3].should == 3

    h[:id1].should == nil
  end
end
