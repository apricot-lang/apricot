describe Apricot::Parser do
  def parse(s)
    @ast = described_class.parse_string(s, "(spec)")
    @first = @ast.elements.first
    @ast.elements
  end

  def parse_one(s)
    parse(s).length.should == 1
  end

  it 'parses nothing' do
    parse('').should be_empty
  end

  it 'skips whitespace' do
    parse(" \n\t,").should be_empty
  end

  it 'skips comments' do
    parse('; example').should be_empty
  end

  it 'discards commented forms' do
    parse('#_form').should be_empty
  end

  it 'parses identifiers' do
    parse_one('example')
    @first.should be_a(Apricot::AST::Identifier)
    @first.name.should == :example
  end

  it 'parses constants' do
    parse_one('Example')
    @first.should be_a(Apricot::AST::Constant)
    @first.names.should == [:Example]
  end

  it 'parses scoped constants' do
    parse_one('Foo::Bar::Baz')
    @first.should be_a(Apricot::AST::Constant)
    @first.names.should == [:Foo, :Bar, :Baz]
  end

  it 'does not parse invalid scoped constants' do
    expect { parse('Foo::') }.to raise_error(Apricot::SyntaxError)
    expect { parse('Foo::::Bar') }.to raise_error(Apricot::SyntaxError)
  end

  it 'parses true, false, and nil' do
    parse('true false nil').length.should == 3
    @ast.elements[0].should be_a(Apricot::AST::TrueLiteral)
    @ast.elements[1].should be_a(Apricot::AST::FalseLiteral)
    @ast.elements[2].should be_a(Apricot::AST::NilLiteral)
  end

  it 'parses fixnums' do
    parse_one('123')
    @first.should be_a(Apricot::AST::FixnumLiteral)
    @first.value.should == 123
  end

  it 'parses bignums' do
    parse_one('12345678901234567890')
    @first.should be_a(Apricot::AST::BignumLiteral)
    @first.value.should == 12345678901234567890
  end

  it 'parses radix integers' do
    parse_one('2r10')
    @first.should be_a(Apricot::AST::FixnumLiteral)
    @first.value.should == 2
  end

  it 'parses floats' do
    parse_one('1.23')
    @first.should be_a(Apricot::AST::FloatLiteral)
    @first.value.should == 1.23
  end

  it 'parses rationals' do
    parse_one('12/34')
    @first.should be_a(Apricot::AST::RationalLiteral)
    @first.numerator.should == 12
    @first.denominator.should == 34
  end

  it 'does not parse invalid numbers' do
    expect { parse('12abc') }.to raise_error(Apricot::SyntaxError)
  end

  it 'parses empty strings' do
    parse_one('""')
    @first.should be_a(Apricot::AST::StringLiteral)
    @first.value.should == ''
  end

  it 'parses strings' do
    parse_one('"Hello, world!"')
    @first.should be_a(Apricot::AST::StringLiteral)
    @first.value.should == 'Hello, world!'
  end

  it 'parses multiline strings' do
    parse_one(%{"This is\na test"})
    @first.should be_a(Apricot::AST::StringLiteral)
    @first.value.should == "This is\na test"
  end

  it 'does not parse unfinished strings' do
    expect { parse('"') }.to raise_error(Apricot::SyntaxError)
  end

  it 'parses strings with character escapes' do
    parse_one('"\\a\\b\\t\\n\\v\\f\\r\\e\\"\\\\"')
    @first.should be_a(Apricot::AST::StringLiteral)
    @first.value.should == "\a\b\t\n\v\f\r\e\"\\"
  end

  it 'parses strings with octal escapes' do
    parse_one('"\\1\\01\\001"')
    @first.should be_a(Apricot::AST::StringLiteral)
    @first.value.should == "\001\001\001"
  end

  it 'parses strings with hex escapes' do
    parse_one('"\\x1\\x01"')
    @first.should be_a(Apricot::AST::StringLiteral)
    @first.value.should == "\001\001"
  end

  it 'does not parse strings with invalid hex escapes' do
    expect { parse('"\\x"') }.to raise_error(Apricot::SyntaxError)
  end

  it 'stops parsing hex/octal escapes in strings at non-hex/octal digits' do
    parse_one('"\xAZ\082"')
    @first.should be_a(Apricot::AST::StringLiteral)
    @first.value.should == "\x0AZ\00082"
  end

  it 'parses symbols' do
    parse_one(':example')
    @first.should be_a(Apricot::AST::SymbolLiteral)
    @first.value.should == :example
  end

  it 'parses quoted symbols' do
    parse_one(':"\x01()"')
    @first.should be_a(Apricot::AST::SymbolLiteral)
    @first.value.should == :"\x01()"
  end

  it 'does not parse unfinished quoted symbols' do
    expect { parse(':"') }.to raise_error(Apricot::SyntaxError)
  end

  it 'does not parse empty symbols' do
    expect { parse(':') }.to raise_error(Apricot::SyntaxError)
    expect { parse(':""') }.to raise_error(Apricot::SyntaxError)
  end

  it 'parses empty lists' do
    parse_one('()')
    @first.should be_a(Apricot::AST::List)
    @first.elements.should be_empty
  end

  it 'parses lists' do
    parse_one('(1 two)')
    @first.should be_a(Apricot::AST::List)
    @first.elements[0].should be_a(Apricot::AST::FixnumLiteral)
    @first.elements[1].should be_a(Apricot::AST::Identifier)
  end

  it 'parses empty arrays' do
    parse_one('[]')
    @first.should be_a(Apricot::AST::ArrayLiteral)
    @first.elements.should be_empty
  end

  it 'parses arrays' do
    parse_one('[1 two]')
    @first.should be_a(Apricot::AST::ArrayLiteral)
    @first.elements[0].should be_a(Apricot::AST::FixnumLiteral)
    @first.elements[1].should be_a(Apricot::AST::Identifier)
  end

  it 'parses empty hashes' do
    parse_one('{}')
    @first.should be_a(Apricot::AST::HashLiteral)
    @first.elements.should be_empty
  end

  it 'parses hashes' do
    parse_one('{:example 1}')
    @first.should be_a(Apricot::AST::HashLiteral)
    @first.elements[0].should be_a(Apricot::AST::SymbolLiteral)
    @first.elements[1].should be_a(Apricot::AST::FixnumLiteral)
  end

  it 'does not parse invalid hashes' do
    expect { parse('{:foo 1 :bar}') }.to raise_error(Apricot::SyntaxError)
  end

  it 'parses empty sets' do
    parse_one('#{}')
    @first.should be_a(Apricot::AST::SetLiteral)
    @first.elements.should be_empty
  end

  it 'parses sets' do
    parse_one('#{1 two}')
    @first.should be_a(Apricot::AST::SetLiteral)
    @first.elements[0].should be_a(Apricot::AST::FixnumLiteral)
    @first.elements[1].should be_a(Apricot::AST::Identifier)
  end

  it 'parses multiple forms' do
    parse('foo bar').length.should == 2
    @ast.elements[0].should be_a(Apricot::AST::Identifier)
    @ast.elements[1].should be_a(Apricot::AST::Identifier)
  end

  it 'parses quoted forms' do
    parse_one("'test")
    @first.should be_a(Apricot::AST::List)
    @first.elements.length.should == 2
    @first.elements[0].should be_a(Apricot::AST::Identifier)
    @first.elements[0].name.should == :quote
    @first.elements[1].should be_a(Apricot::AST::Identifier)
    @first.elements[1].name.should == :test
  end
end
