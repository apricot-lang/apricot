describe Apricot::List do
  def new_list(*args)
    described_class[*args]
  end

  def empty_list
    described_class::EmptyList
  end

  it 'has a single instance of the empty list' do
    new_list.object_id.should == empty_list.object_id
    new_list(1,2).tail.tail.object_id.should == empty_list.object_id
  end

  it 'can be built up with cons' do
    list = empty_list.cons(3).cons(2).cons(1)
    list.head.should == 1
    list.tail.head.should == 2
    list.tail.tail.head.should == 3
  end

  it 'supports the == operator' do
    empty_list.should == new_list
    new_list.should == empty_list

    list123 = new_list(1,2,3)
    list23 = new_list(2,3)

    list123.should == list23.cons(1)
    list23.cons(1).should == list123

    list23.tail.tail.should == empty_list
    empty_list.should == list23.tail.tail

    list123.should_not == empty_list
    empty_list.should_not == list123

    empty_list.should_not == 42
    list123.should_not == 42
  end

  it 'responds to #empty?' do
    new_list.should be_empty
    empty_list.should be_empty
  end

  it 'supports Enumerable methods' do
    list = new_list(1,2,3)

    foo = []
    list.each {|x| foo << x }
    foo.should == [1,2,3]

    list.to_a.should == [1,2,3]
    list.count.should == 3
    list.map {|x| x + x }.should == [2,4,6]
  end

  it 'can be inspected' do
    list = new_list(1,2,3)
    list.inspect.should == "(1 2 3)"
    list.tail.tail.inspect.should == "(3)"
    empty_list.inspect.should == "()"
  end

  it 'copies its tail when copied' do
    list1 = new_list(1,2)
    list2 = list1.dup

    list1.object_id.should_not == list2.object_id
    list1.tail.object_id.should_not == list2.tail.object_id
  end

  it 'does not copy the empty list in its tail when copied' do
    list = new_list(1).dup

    list.tail.object_id.should == empty_list.object_id
  end
end
