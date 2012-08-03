describe Apricot::Parser do
  def parse(s)
    @ast = described_class.parse_string(s, "(spec)")
    @first = @ast.elements.first
    @ast.elements
  end

  def parse_one(s, klass)
    parse(s).length.should == 1
    @first.should be_a(klass)
    @first
  end

  def expect_syntax_error(s)
    expect { parse(s) }.to raise_error(Apricot::SyntaxError)
  end

  it 'parses nothing' do
    parse('').should be_empty
  end

  it 'skips whitespace' do
    parse(" \n\t,").should be_empty
  end

  it 'skips comments' do
    parse('; example').should be_empty
    parse('#!/usr/bin/env apricot').should be_empty
  end

  it 'discards commented forms' do
    parse('#_form').should be_empty
  end

  it 'parses identifiers' do
    parse_one('example', Apricot::AST::Identifier)
    @first.name.should == :example
  end

  it 'parses constants' do
    parse_one('Example', Apricot::AST::Constant)
    @first.names.should == [:Example]
  end

  it 'does not parse invalid constants' do
    expect_syntax_error 'Fo$o'
  end

  it 'parses scoped constants' do
    parse_one('Foo::Bar::Baz', Apricot::AST::Constant)
    @first.names.should == [:Foo, :Bar, :Baz]
  end

  it 'does not parse invalid scoped constants' do
    expect_syntax_error 'Foo::'
    expect_syntax_error 'Foo:'
    expect_syntax_error 'Foo::a'
    expect_syntax_error 'Foo::::Bar'
  end

  it 'parses true, false, nil, and self' do
    parse('true false nil self').length.should == 4
    @ast[0].should be_a(Apricot::AST::Literal)
    @ast[0].value.should == :true
    @ast[1].should be_a(Apricot::AST::Literal)
    @ast[1].value.should == :false
    @ast[2].should be_a(Apricot::AST::Literal)
    @ast[2].value.should == :nil
    @ast[3].should be_a(Apricot::AST::Identifier)
    @ast[3].name.should == :self
  end

  it 'parses fixnums' do
    parse_one('123', Apricot::AST::Literal)
    @first.value.should == 123
  end

  it 'parses bignums' do
    parse_one('12345678901234567890', Apricot::AST::BignumLiteral)
    @first.value.should == 12345678901234567890
  end

  it 'parses radix integers' do
    parse_one('2r10', Apricot::AST::Literal)
    @first.value.should == 2
  end

  it 'parses floats' do
    parse_one('1.23', Apricot::AST::FloatLiteral)
    @first.value.should == 1.23
  end

  it 'parses rationals' do
    parse_one('12/34', Apricot::AST::RationalLiteral)
    @first.numerator.should == 12
    @first.denominator.should == 34
  end

  it 'does not parse invalid numbers' do
    expect_syntax_error '12abc'
  end

  it 'parses empty strings' do
    parse_one('""', Apricot::AST::StringLiteral)
    @first.value.should == ''
  end

  it 'parses strings' do
    parse_one('"Hello, world!"', Apricot::AST::StringLiteral)
    @first.value.should == 'Hello, world!'
  end

  it 'parses multiline strings' do
    parse_one(%{"This is\na test"}, Apricot::AST::StringLiteral)
    @first.value.should == "This is\na test"
  end

  it 'does not parse unfinished strings' do
    expect_syntax_error '"'
  end

  it 'parses strings with character escapes' do
    parse_one('"\\a\\b\\t\\n\\v\\f\\r\\e\\"\\\\"', Apricot::AST::StringLiteral)
    @first.value.should == "\a\b\t\n\v\f\r\e\"\\"
  end

  it 'parses strings with octal escapes' do
    parse_one('"\\1\\01\\001"', Apricot::AST::StringLiteral)
    @first.value.should == "\001\001\001"
  end

  it 'parses strings with hex escapes' do
    parse_one('"\\x1\\x01"', Apricot::AST::StringLiteral)
    @first.value.should == "\001\001"
  end

  it 'does not parse strings with invalid hex escapes' do
    expect_syntax_error '"\\x"'
  end

  it 'stops parsing hex/octal escapes in strings at non-hex/octal digits' do
    parse_one('"\xAZ\082"', Apricot::AST::StringLiteral)
    @first.value.should == "\x0AZ\00082"
  end

  it 'parses regexes' do
    parse_one('#r!!', Apricot::AST::RegexLiteral).pattern.should == ''
    parse_one('#r!egex!', Apricot::AST::RegexLiteral).pattern.should == 'egex'
    parse_one('#r(egex)', Apricot::AST::RegexLiteral).pattern.should == 'egex'
    parse_one('#r[egex]', Apricot::AST::RegexLiteral).pattern.should == 'egex'
    parse_one('#r{egex}', Apricot::AST::RegexLiteral).pattern.should == 'egex'
    parse_one('#r<egex>', Apricot::AST::RegexLiteral).pattern.should == 'egex'
    parse_one('#r!\!!', Apricot::AST::RegexLiteral).pattern.should == '!'
    parse_one('#r!foo\bar!', Apricot::AST::RegexLiteral).pattern.should == 'foo\bar'
    parse_one('#r!\\\\!', Apricot::AST::RegexLiteral).pattern.should == "\\\\"
  end

  it 'parses regexes with trailing options' do
    parse_one('#r//i', Apricot::AST::RegexLiteral)
    @first.options.should == Regexp::IGNORECASE
    parse_one('#r/foo/x', Apricot::AST::RegexLiteral)
    @first.options.should == Regexp::EXTENDED
    parse_one('#r//im', Apricot::AST::RegexLiteral)
    @first.options.should == Regexp::IGNORECASE | Regexp::MULTILINE
  end

  it 'does not parse regexes with unknown trailing options' do
    expect_syntax_error '#r/foo/asdf'
  end

  it 'parses symbols' do
    parse_one(':example', Apricot::AST::SymbolLiteral)
    @first.value.should == :example
  end

  it 'parses quoted symbols' do
    parse_one(':"\x01()"', Apricot::AST::SymbolLiteral)
    @first.value.should == :"\x01()"
  end

  it 'does not parse unfinished quoted symbols' do
    expect_syntax_error ':"'
  end

  it 'does not parse empty symbols' do
    expect_syntax_error ':'
  end

  it 'does parse empty quoted symbols' do
    parse_one(':""', Apricot::AST::SymbolLiteral)
    @first.value.should == :""
  end

  it 'parses empty lists' do
    parse_one('()', Apricot::AST::List)
    @first.elements.should be_empty
  end

  it 'parses lists' do
    parse_one('(1 two)', Apricot::AST::List)
    @first[0].should be_a(Apricot::AST::Literal)
    @first[1].should be_a(Apricot::AST::Identifier)
  end

  it 'parses empty arrays' do
    parse_one('[]', Apricot::AST::ArrayLiteral)
    @first.elements.should be_empty
  end

  it 'parses arrays' do
    parse_one('[1 two]', Apricot::AST::ArrayLiteral)
    @first[0].should be_a(Apricot::AST::Literal)
    @first[1].should be_a(Apricot::AST::Identifier)
  end

  it 'parses empty hashes' do
    parse_one('{}', Apricot::AST::HashLiteral)
    @first.elements.should be_empty
  end

  it 'parses hashes' do
    parse_one('{:example 1}', Apricot::AST::HashLiteral)
    @first[0].should be_a(Apricot::AST::SymbolLiteral)
    @first[1].should be_a(Apricot::AST::Literal)
  end

  it 'does not parse invalid hashes' do
    expect_syntax_error '{:foo 1 :bar}'
  end

  it 'parses empty sets' do
    parse_one('#{}', Apricot::AST::SetLiteral)
    @first.elements.should be_empty
  end

  it 'parses sets' do
    parse_one('#{1 two}', Apricot::AST::SetLiteral)
    @first[0].should be_a(Apricot::AST::Literal)
    @first[1].should be_a(Apricot::AST::Identifier)
  end

  it 'parses multiple forms' do
    parse('foo bar').length.should == 2
    @ast[0].should be_a(Apricot::AST::Identifier)
    @ast[1].should be_a(Apricot::AST::Identifier)
  end

  it 'parses quoted forms' do
    parse_one("'test", Apricot::AST::List)
    @first.elements.length.should == 2
    @first[0].should be_a(Apricot::AST::Identifier)
    @first[0].name.should == :quote
    @first[1].should be_a(Apricot::AST::Identifier)
    @first[1].name.should == :test
  end

  it 'parses #() shorthand' do
    Apricot.stub(:gensym).and_return(*:a..:z)

    parse("#()").should == parse("(fn [] ())")
    parse("#(foo)").should == parse("(fn [] (foo))")
    parse("#(%)").should == parse("(fn [a] (a))")
    parse("#(% %2)").should == parse("(fn [b c] (b c))")
    parse("#(%1 %2)").should == parse("(fn [d e] (d e))")
    parse("#(%2)").should == parse("(fn [g f] (f))")
    parse("#(%&)").should == parse("(fn [& h] (h))")
    parse("#(% %&)").should == parse("(fn [i & j] (i j))")

    expect_syntax_error("#(%0)")
    expect_syntax_error("#(%-1)")
    expect_syntax_error("#(%x)")
    expect_syntax_error("#(%1.1)")
    expect_syntax_error("#(%1asdf)")
  end
end
