describe Apricot::Identifier do
  def new_id(name)
    described_class.new name
  end

  it 'supports the == operator' do
    id1 = new_id :id1
    id2 = new_id :id1
    id3 = new_id :id3

    id1.should == id2
    id2.should == id1

    id1.should_not == id3
    id3.should_not == id1

    id1.should_not == 42
  end

  it 'can be inspected' do
    new_id(:test).inspect.should == "test"
  end

  it 'can be used as a key in Hashes' do
    id1 = new_id :id1
    id2 = new_id :id1
    id3 = new_id :id3
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
