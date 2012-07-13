module Apricot
  class SyntaxError < StandardError
    attr_accessor :filename, :line, :msg

    def initialize(filename, line, msg)
      @filename = filename
      @line = line
      @msg = msg
    end

    def to_s
      "#{@filename}:#{@line}: #{@msg}"
    end
  end

  class Parser
    IDENTIFIER   = /[A-Za-z0-9`~!@#\$%^&*_=+<.>\/?:\\|-]/
    OCTAL        = /[0-7]/
    HEX          = /[0-9a-fA-F]/
    DIGITS       = ('0'..'9').to_a + ('a'..'z').to_a
    CHAR_ESCAPES = {"a" => "\a", "b" => "\b", "t" => "\t", "n" => "\n",
                    "v" => "\v", "f" => "\f", "r" => "\r", "e" => "\e"}

    # @param [String] source a source program
    def initialize(source, filename = "(none)")
      @filename = filename
      @source = source
      @location = 0
      @line = 1
    end

    def self.parse_file(filename)
      new(File.read(filename), filename).parse
    end

    def self.parse_string(source, filename = "(none)")
      new(source, filename).parse
    end

    # @return [Array<AST::Node>] a list of the forms in the program
    def parse
      program = []
      next_char

      skip_whitespace
      while @char
        program << parse_form
        skip_whitespace
      end

      Apricot::AST::Root.new program
    end

    private
    # Parse Lisp forms until the given character is encountered
    # @param [String] terminator the character to stop parsing at
    # @return [Array<AST::Node>] a list of the Lisp forms parsed
    def parse_forms_until(terminator)
      skip_whitespace
      forms = []

      while @char
        if @char == terminator
          next_char # consume the terminator
          return forms
        end

        forms << parse_form
        skip_whitespace
      end

      # Can only reach here if we run out of chars without getting a terminator
      syntax_error "Unexpected end of program, expected #{terminator}"
    end

    # Parse a single Lisp form
    # @return [AST::Node] an AST node representing the form
    def parse_form
      case @char
      when "'" then parse_quote
      when '(' then parse_list
      when '[' then parse_array
      when '{' then parse_hash
      when '"' then parse_string
      when ':' then parse_symbol
      when /\d/ then parse_number
      when IDENTIFIER
        if @char =~ /[+-]/ && peek_char =~ /\d/
          parse_number
        else
          parse_identifier
        end
      else syntax_error "Unexpected character: #{@char}"
      end
    end

    # Skips whitespace, commas, and comments
    def skip_whitespace
      while @char =~ /[\s,;]/
        # Comments begin with a semicolon and extend to the end of the line
        if @char == ';'
          while @char && @char != "\n"
            next_char
          end
        else
          next_char
        end
      end
    end

    def parse_quote
      next_char # skip the '
      form = parse_form
      quote = AST::Identifier.new(@line, :quote)
      AST::List.new(@line, [quote, form])
    end

    def parse_list
      next_char # skip the (
      AST::List.new(@line, parse_forms_until(')'))
    end

    def parse_array
      next_char # skip the [
      AST::Array.new(@line, parse_forms_until(']'))
    end

    def parse_hash
      next_char # skip the {
      forms = parse_forms_until('}')
      syntax_error "Odd number of forms in key-value hash" if forms.count.odd?
      AST::Hash.new(@line, forms)
    end

    def parse_string
      line = @line
      next_char # skip the opening "
      string = ""

      while @char
        if @char == '"'
          next_char # consume the "
          return AST::StringLiteral.new(line, string)
        end

        string << parse_string_char
      end

      # Can only reach here if we run out of chars without getting a "
      syntax_error "Unexpected end of program while parsing string"
    end

    def parse_string_char
      char = if @char == "\\"
               next_char
               if CHAR_ESCAPES.has_key?(@char)
                 CHAR_ESCAPES[consume_char]
               elsif @char =~ OCTAL
                 char_escape_helper(8, OCTAL, 3)
               elsif @char == 'x'
                 next_char
                 syntax_error "Invalid hex character escape" unless @char =~ HEX
                 char_escape_helper(16, HEX, 2)
               else
                 consume_char
               end
             else
               consume_char
             end
      syntax_error "Unexpected end of file while parsing character escape" unless char
      char
    end

    # Parse digits in a certain base for string character escapes
    def char_escape_helper(base, regex, n)
      number = ""

      n.times do
        number << @char
        next_char
        break if @char !~ regex
      end

      number.to_i(base).chr
    end

    def parse_symbol
      next_char # skip the :
      symbol = ""

      while @char =~ IDENTIFIER
        symbol << @char
        next_char
      end

      syntax_error "Empty symbol name" if symbol.empty?

      AST::SymbolLiteral.new(@line, symbol.to_sym)
    end

    def parse_number
      number = ""

      while @char =~ IDENTIFIER
        number << @char
        next_char
      end

      case number
      when /^[+-]?\d+$/
        AST::IntegerLiteral.new(@line, number.to_i)
      when /^([+-]?)(\d+)r([a-zA-Z0-9]+)$/
        sign, radix, digits = $1, $2.to_i, $3
        syntax_error "Radix out of range: #{radix}" unless 2 <= radix && radix <= 36
        syntax_error "Invalid digits for radix in number: #{number}" unless digits.downcase.chars.all? {|d| DIGITS[0..radix-1].include?(d) }
        AST::IntegerLiteral.new(@line, (sign + digits).to_i(radix))
      when /^[+-]?\d+\.?\d*(?:e[+-]?\d+)?$/
        AST::FloatLiteral.new(@line, number.to_f)
      when /^([+-]?\d+)\/(\d+)$/
        AST::RationalLiteral.new(@line, $1.to_i, $2.to_i)
      else
        syntax_error "Invalid number: #{number}"
      end
    end

    def parse_identifier
      identifier = ""

      while @char =~ IDENTIFIER
        identifier << @char
        next_char
      end

      identifier = identifier.to_sym

      case identifier
      when :true
        AST::TrueLiteral.new(@line)
      when :false
        AST::FalseLiteral.new(@line)
      when :nil
        AST::NilLiteral.new(@line)
      else
        AST::Identifier.new(@line, identifier)
      end
    end

    def consume_char
      char = @char
      next_char
      char
    end

    def next_char
      @line += 1 if @char == "\n"
      @char = @source[@location,1]
      @char = nil if @char.empty?
      @location += 1 if @char
      @char
    end

    def peek_char
      char = @source[@location,1]
      char = nil if char.empty?
      char
    end

    def syntax_error(message)
      raise SyntaxError.new(@filename, @line, message)
    end
  end
end
