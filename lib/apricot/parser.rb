require 'stringio'

module Apricot
  class Parser
    IDENTIFIER   = /[A-Za-z0-9`~!@#\$%^&*_=+<.>\/?:\\|-]/
    OCTAL        = /[0-7]/
    HEX          = /[0-9a-fA-F]/
    DIGITS       = ('0'..'9').to_a + ('a'..'z').to_a
    CHAR_ESCAPES = {"a" => "\a", "b" => "\b", "t" => "\t", "n" => "\n",
                    "v" => "\v", "f" => "\f", "r" => "\r", "e" => "\e"}
    REGEXP_OPTIONS = {'i' => Regexp::IGNORECASE, 'x' => Regexp::EXTENDED,
                      'm' => Regexp::MULTILINE}

    FnState = Struct.new(:args, :rest)

    # @param [IO] io an input stream object to read forms from
    def initialize(io, filename = "(none)", line = 1)
      @filename = filename
      @io = io
      @location = 0
      @line = line

      @fn_state = []
    end

    def self.parse_file(filename)
      File.open(filename) {|f| new(f, filename).parse }
    end

    def self.parse_string(source, filename = "(none)", line = 1)
      new(StringIO.new(source, "r"), filename, line).parse
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

      Apricot::AST::TopLevel.new(program, @filename)
    end

    # @return AST::Node an AST node representing the form read
    def parse_one
      next_char
      skip_whitespace
      parse_form
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
      incomplete_error "Unexpected end of program, expected #{terminator}"
    end

    # Parse a single Lisp form
    # @return [AST::Node] an AST node representing the form
    def parse_form
      case @char
      when '#' then parse_dispatch
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
        elsif @char =~ /[A-Z]/
          parse_constant
        else
          parse_identifier
        end
      else syntax_error "Unexpected character: #{@char}"
      end
    end

    def parse_dispatch
      next_char # skip #
      case @char
      when '|' then parse_pipe_identifier
      when '{' then parse_set
      when '(' then parse_fn
      when 'r' then parse_regex
      when 'q' then parse_quotation(false)
      when 'Q' then parse_quotation(true)
      else syntax_error "Unknown reader macro: ##{@char}"
      end
    end

    # Skips whitespace, commas, and comments
    def skip_whitespace
      while @char =~ /[\s,;#]/
        # Comments begin with a semicolon and extend to the end of the line
        # Treat #! as a comment for shebang lines
        if @char == ';' || (@char == '#' && peek_char == '!')
          while @char && @char != "\n"
            next_char
          end
        elsif @char == '#'
          break unless peek_char == '_'
          next_char; next_char # skip #_
          skip_whitespace
          incomplete_error "Unexpected end of program after #_, expected a form" unless @char
          parse_form # discard next form
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

    def parse_fn
      @fn_state << FnState.new([], nil)
      body = parse_list
      state = @fn_state.pop

      state.args << :'&' << state.rest if state.rest
      args = state.args.map.with_index do |x, i|
        AST::Identifier.new(body.line, x || Apricot.gensym("p#{i + 1}"))
      end

      AST::List.new(body.line, [AST::Identifier.new(body.line, :fn),
                                AST::ArrayLiteral.new(body.line, args),
                                body])
    end

    def parse_list
      next_char # skip the (
      AST::List.new(@line, parse_forms_until(')'))
    end

    def parse_array
      next_char # skip the [
      AST::ArrayLiteral.new(@line, parse_forms_until(']'))
    end

    def parse_hash
      next_char # skip the {
      forms = parse_forms_until('}')
      syntax_error "Odd number of forms in key-value hash" if forms.count.odd?
      AST::HashLiteral.new(@line, forms)
    end

    def parse_set
      next_char # skip the {
      AST::SetLiteral.new(@line, parse_forms_until('}'))
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
      incomplete_error "Unexpected end of program while parsing string"
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
      incomplete_error "Unexpected end of file while parsing character escape" unless char
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

    def delimiter_helper(c)
      case c
      when '(' then ')'
      when '[' then ']'
      when '{' then '}'
      when '<' then '>'
      else c
      end
    end

    def parse_regex
      line = @line
      next_char # skip the r
      delimiter = delimiter_helper(@char)
      next_char # skip delimiter
      regex = ""

      while @char
        if @char == delimiter
          next_char # consume delimiter
          options = regex_options_helper
          return AST::RegexLiteral.new(line, regex, options)
        elsif @char == "\\" && peek_char == delimiter
          next_char
        elsif @char == "\\" && peek_char == "\\"
          regex << consume_char
        end
        regex << consume_char
      end

      incomplete_error "Unexpected end of program while parsing regex"
    end

    def regex_options_helper
      options = 0

      while @char =~ /[a-zA-Z]/
        if option = REGEXP_OPTIONS[@char]
          options |= option
        else
          syntax_error "Unknown regexp option: '#{@char}'"
        end

        next_char
      end

      options
    end

    def parse_quotation(double_quote)
      line = @line
      next_char # skip the prefix
      delimiter = delimiter_helper(@char)
      next_char # skip delimiter
      string = ""

      while @char
        if @char == delimiter
          next_char # consume delimiter
          return AST::StringLiteral.new(line, string)
        end

        if double_quote
          string << parse_string_char
        elsif @char == "\\" && peek_char == delimiter
          next_char
          string << consume_char
        else
          string << consume_char
        end
      end

      incomplete_error "Unexpected end of program while parsing quotation"
    end

    def parse_symbol
      line = @line
      next_char # skip the :
      symbol = ""

      if @char == '"'
        next_char # skip opening "
        while @char
          break if @char == '"'
          symbol << parse_string_char
        end
        incomplete_error "Unexpected end of program while parsing symbol" unless @char == '"'
        next_char # skip closing "
      else
        while @char =~ IDENTIFIER
          symbol << @char
          next_char
        end

        syntax_error "Empty symbol name" if symbol.empty?
      end

      AST::SymbolLiteral.new(line, symbol.to_sym)
    end

    def parse_number
      number = ""

      while @char =~ IDENTIFIER
        number << @char
        next_char
      end

      case number
      when /^[+-]?\d+$/
        AST.new_integer(@line, number.to_i)
      when /^([+-]?)(\d+)r([a-zA-Z0-9]+)$/
        sign, radix, digits = $1, $2.to_i, $3
        syntax_error "Radix out of range: #{radix}" unless 2 <= radix && radix <= 36
        syntax_error "Invalid digits for radix in number: #{number}" unless digits.downcase.chars.all? {|d| DIGITS[0..radix-1].include?(d) }
        AST.new_integer(@line, (sign + digits).to_i(radix))
      when /^[+-]?\d+\.?\d*(?:e[+-]?\d+)?$/
        AST::FloatLiteral.new(@line, number.to_f)
      when /^([+-]?\d+)\/(\d+)$/
        AST::RationalLiteral.new(@line, $1.to_i, $2.to_i)
      else
        syntax_error "Invalid number: #{number}"
      end
    end

    def parse_constant
      constant = ""

      while @char =~ IDENTIFIER
        constant << @char
        next_char
      end

      # A negative second argument to String#split means it won't trim empty
      # strings off the end, so we can check for them afterwards.
      names = constant.split('::', -1)

      unless names.all? {|n| n =~ /^[A-Z]\w*$/ }
        syntax_error "Invalid constant: #{constant}"
      end

      names.map! {|x| x.to_sym }

      AST::Constant.new(@line, names)
    end

    def parse_identifier
      identifier = ""

      while @char =~ IDENTIFIER
        identifier << @char
        next_char
      end

      # Handle % identifiers in #() syntax
      if (state = @fn_state.last) && identifier[0] == '%'
        identifier = case identifier[1..-1]
        when '' # % is equivalent to %1
          state.args[0] ||= Apricot.gensym('p1')
        when '&'
          state.rest ||= Apricot.gensym('rest')
        when /^[1-9]\d*$/
          n = identifier[1..-1].to_i
          state.args[n - 1] ||= Apricot.gensym("p#{n}")
        else
          syntax_error "arg literal must be %, %& or %integer"
        end
      else
        identifier = identifier.to_sym
      end

      case identifier
      when :true, :false, :nil
        AST::Literal.new(@line, identifier)
      else
        AST::Identifier.new(@line, identifier)
      end
    end

    def parse_pipe_identifier
      line = @line
      next_char # skip the |
      identifier = ""

      while @char
        if @char == '|'
          next_char # consume the |
          return AST::Identifier.new(line, identifier.to_sym)
        end

        identifier << parse_string_char
      end

      incomplete_error "Unexpected end of program while parsing pipe identifier"
    end

    def consume_char
      char = @char
      next_char
      char
    end

    def next_char
      @line += 1 if @char == "\n"
      @char = @io.getc
      return nil unless @char
      @location += 1
      # .chr shouldn't be necessary (rubinius issue #1847)
      @char = @char.chr
    end

    def peek_char
      char = @io.getc
      return nil unless char
      @io.ungetc char
      # .chr shouldn't be necessary (rubinius issue #1847)
      char.chr
    end

    def syntax_error(message)
      raise SyntaxError.new(@filename, @line, message)
    end

    def incomplete_error(message)
      raise SyntaxError.new(@filename, @line, message, true)
    end
  end
end
