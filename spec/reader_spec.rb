describe Apricot::Reader do
  def read(s)
    @forms = described_class.read_string(s, "(spec)")
    @first = @forms.first
    @forms
  end

  def read_one(s, klass = nil)
    read(s).length.should == 1
    @first.should be_a(klass) if klass
    @first
  end

  def expect_syntax_error(s)
    expect { read(s) }.to raise_error(Apricot::SyntaxError)
  end

  it 'reads nothing' do
    read('').should be_empty
  end

  it 'skips whitespace' do
    read(" \n\t,").should be_empty
  end

  it 'skips comments' do
    read('; example').should be_empty
    read('#!/usr/bin/env apricot').should be_empty
  end

  it 'discards commented forms' do
    read('#_form').should be_empty
  end

  it 'reads identifiers' do
    read_one('example', Identifier)
    @first.name.should == :example
  end

  it 'reads pipe identifiers' do
    read_one('#|example|').should == Identifier.intern(:example)
    read_one('#|foo bar|').should == Identifier.intern(:"foo bar")
    read_one('#|foo\nbar|')
    @first.should == Identifier.intern(:"foo\nbar")
    read_one('#|foo\|bar|').should == Identifier.intern(:"foo|bar")
    read_one('#|foo"bar|').should == Identifier.intern(:'foo"bar')
  end

  it 'reads constants' do
    read_one('Example', Identifier)
    @first.constant?.should be_true
    @first.const_names.should == [:Example]
  end

  it 'reads invalid constants as identifiers' do
    read_one('Fo$o', Identifier)
    @first.constant?.should be_false
  end

  it 'reads scoped constants' do
    read_one('Foo::Bar::Baz', Identifier)
    @first.constant?.should be_true
    @first.const_names.should == [:Foo, :Bar, :Baz]
  end

  it 'reads invalid scoped constants as identifiers' do
    read_one('Foo::', Identifier)
    @first.constant?.should be_false
    read_one('Foo:', Identifier)
    @first.constant?.should be_false
    read_one('Foo::a', Identifier)
    @first.constant?.should be_false
    read_one('Foo::::Bar', Identifier)
    @first.constant?.should be_false
  end

  it 'reads true, false, nil, and self' do
    read('true false nil self').length.should == 4
    @forms[0].should == true
    @forms[1].should == false
    @forms[2].should == nil
    @forms[3].should == Identifier.intern(:self)
  end

  it 'reads fixnums' do
    read_one('123').should == 123
  end

  it 'reads bignums' do
    read_one('12345678901234567890').should == 12345678901234567890
  end

  it 'reads radix integers' do
    read_one('2r10').should == 2
  end

  it 'reads floats' do
    read_one('1.23').should == 1.23
  end

  it 'reads rationals' do
    read_one('12/34').should == Rational(12, 34)
  end

  it 'does not read invalid numbers' do
    expect_syntax_error '12abc'
  end

  it 'reads empty strings' do
    read_one('""', String).should == ''
  end

  it 'reads strings' do
    read_one('"Hello, world!"').should == 'Hello, world!'
  end

  it 'reads multiline strings' do
    read_one(%{"This is\na test"}).should == "This is\na test"
  end

  it 'does not read unfinished strings' do
    expect_syntax_error '"'
  end

  it 'reads strings with character escapes' do
    read_one('"\\a\\b\\t\\n\\v\\f\\r\\e\\"\\\\"').should == "\a\b\t\n\v\f\r\e\"\\"
  end

  it 'reads strings with octal escapes' do
    read_one('"\\1\\01\\001"').should == "\001\001\001"
  end

  it 'reads strings with hex escapes' do
    read_one('"\\x1\\x01"').should == "\001\001"
  end

  it 'does not read strings with invalid hex escapes' do
    expect_syntax_error '"\\x"'
  end

  it 'stops parsing hex/octal escapes in strings at non-hex/octal digits' do
    read_one('"\xAZ\082"').should == "\x0AZ\00082"
  end

  it 'reads regexes' do
    read_one('#r!!').should == //
    read_one('#r!egex!').should == /egex/
    read_one('#r(egex)').should == /egex/
    read_one('#r[egex]').should == /egex/
    read_one('#r{egex}').should == /egex/
    read_one('#r<egex>').should == /egex/
    read_one('#r!\!!').should == /!/
    read_one('#r!foo\bar!').should == /foo\bar/
    read_one('#r!\\\\!').should == /\\/
  end

  it 'reads regexes with trailing options' do
    read_one('#r//i', Regexp)
    @first.options.should == Regexp::IGNORECASE
    read_one('#r/foo/x', Regexp)
    @first.options.should == Regexp::EXTENDED
    read_one('#r//im', Regexp)
    @first.options.should == Regexp::IGNORECASE | Regexp::MULTILINE
  end

  it 'does not read regexes with unknown trailing options' do
    expect_syntax_error '#r/foo/asdf'
  end

  it 'reads symbols' do
    read_one(':example').should == :example
  end

  it 'reads quoted symbols' do
    read_one(':"\x01()"').should == :"\x01()"
  end

  it 'does not read unfinished quoted symbols' do
    expect_syntax_error ':"'
  end

  it 'does not read empty symbols' do
    expect_syntax_error ':'
  end

  it 'does read empty quoted symbols' do
    read_one(':""').should == :""
  end

  it 'reads empty lists' do
    read_one('()').should == List[]
  end

  it 'reads lists' do
    read_one('(1 two)').should == List[1, Identifier.intern(:two)]
  end

  it 'reads empty arrays' do
    read_one('[]').should == []
  end

  it 'reads arrays' do
    read_one('[1 two]').should == [1, Identifier.intern(:two)]
  end

  it 'reads empty hashes' do
    read_one('{}').should == {}
  end

  it 'reads hashes' do
    read_one('{:example 1}').should == {example: 1}
  end

  it 'does not read invalid hashes' do
    expect_syntax_error '{:foo 1 :bar}'
  end

  it 'reads empty sets' do
    read_one('#{}').should == Set[]
  end

  it 'reads sets' do
    read_one('#{1 two}').should == Set[1, Identifier.intern(:two)]
  end

  it 'reads multiple forms' do
    read('foo bar').length.should == 2
    @forms[0].should == Identifier.intern(:foo)
    @forms[1].should == Identifier.intern(:bar)
  end

  it 'reads quoted forms' do
    read_one("'test").should == List[Identifier.intern(:quote), Identifier.intern(:test)]
  end

  it 'reads syntax quoted forms' do
    begin
      old_gensym = Apricot.instance_variable_get :@gensym
      Apricot.instance_variable_set :@gensym, 41

      read_one("`(foo ~bar ~@baz quux#)").should ==
        List[Identifier.intern(:concat),
          List[Identifier.intern(:list),
            List[Identifier.intern(:quote),
              Identifier.intern(:foo)]],
          List[Identifier.intern(:list),
            Identifier.intern(:bar)],
          Identifier.intern(:baz),
          List[Identifier.intern(:list),
            List[Identifier.intern(:quote),
              Identifier.intern(:'quux#__42')]]]
    ensure
      Apricot.instance_variable_set :@gensym, old_gensym
    end
  end

  it 'reads #() shorthand' do
    ids = (:a..:z).map {|sym| Identifier.intern(sym) }
    Apricot.stub(:gensym).and_return(*ids)

    read("#()").should == read("(fn [] ())")
    read("#(foo)").should == read("(fn [] (foo))")
    read("#(%)").should == read("(fn [a] (a))")
    read("#(% %2)").should == read("(fn [b c] (b c))")
    read("#(%1 %2)").should == read("(fn [d e] (d e))")
    read("#(%2)").should == read("(fn [g f] (f))")
    read("#(%&)").should == read("(fn [& h] (h))")
    read("#(% %&)").should == read("(fn [i & j] (i j))")

    expect_syntax_error("#(%0)")
    expect_syntax_error("#(%-1)")
    expect_syntax_error("#(%x)")
    expect_syntax_error("#(%1.1)")
    expect_syntax_error("#(%1asdf)")
  end
end
