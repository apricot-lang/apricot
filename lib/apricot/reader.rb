require 'stringio'

module Apricot
  class Reader
    IDENTIFIER   = /[^'`~()\[\]{}";,\s]/
    OCTAL        = /[0-7]/
    HEX          = /[0-9a-fA-F]/
    DIGITS       = ('0'..'9').to_a + ('a'..'z').to_a

    CHAR_ESCAPES = {
      "a" => "\a", "b" => "\b", "t" => "\t", "n" => "\n",
      "v" => "\v", "f" => "\f", "r" => "\r", "e" => "\e"
    }

    REGEXP_OPTIONS = {
      'i' => Regexp::IGNORECASE,
      'x' => Regexp::EXTENDED,
      'm' => Regexp::MULTILINE
    }

    QUOTE = Identifier.intern(:quote)
    UNQUOTE = Identifier.intern(:unquote)
    UNQUOTE_SPLICING = Identifier.intern(:'unquote-splicing')
    CONCAT = Identifier.intern(:concat)
    APPLY = Identifier.intern(:apply)
    LIST = Identifier.intern(:list)
    FN = Identifier.intern(:fn)

    FnState = Struct.new(:args, :rest)

    # @param [IO] io an input stream object to read forms from
    def initialize(io, filename = '(none)', line = 1)
      @filename = filename
      @io = io
      @location = 0
      @line = line

      @fn_state = []

      # Read the first character
      next_char
    end

    def self.read_file(filename)
      File.open(filename) {|f| new(f, filename).read }
    end

    def self.read_string(source, filename = '(none)', line = 1)
      new(StringIO.new(source), filename, line).read
    end

    # Return a list of the forms that were read.
    def read
      forms = []

      skip_whitespace
      while @char
        forms << read_form
        skip_whitespace
      end

      forms
    end

    def read_one
      skip_whitespace
      form = read_form

      # Unget the last character because the reader always reads one character
      # ahead.
      @io.ungetc(@char) if @char

      form
    end

    private

    # Read forms until the given character is encountered
    def read_forms_until(terminator)
      skip_whitespace
      forms = []

      while @char
        if @char == terminator
          next_char # consume the terminator
          return forms
        end

        forms << read_form
        skip_whitespace
      end

      # Can only reach here if we run out of chars without getting a terminator
      incomplete_error "Unexpected end of program, expected #{terminator}"
    end

    # Read a single Lisp form
    def read_form
      case @char
      when '#' then read_dispatch
      when "'" then read_quote
      when "`" then read_syntax_quote
      when "~" then read_unquote
      when '(' then read_list
      when '[' then read_array
      when '{' then read_hash
      when '"' then read_string
      when ':' then read_symbol
      when /\d/ then read_number
      when IDENTIFIER
        if @char =~ /[+-]/ && peek_char =~ /\d/
          read_number
        else
          read_identifier
        end
      else syntax_error "Unexpected character: #{@char}"
      end
    end

    def read_dispatch
      next_char # skip #
      case @char
      when '|' then read_pipe_identifier
      when '{' then read_set
      when '(' then read_fn
      when 'r' then read_regex
      when 'q' then read_quotation(false)
      when 'Q' then read_quotation(true)
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
          read_form # discard next form
        else
          next_char
        end
      end
    end

    def read_quote
      next_char # skip the '
      skip_whitespace
      incomplete_error "Unexpected end of program after quote ('), expected a form" unless @char

      with_location List[QUOTE, read_form]
    end

    def read_syntax_quote
      next_char # skip the `
      skip_whitespace
      incomplete_error "Unexpected end of program after syntax quote (`), expected a form" unless @char

      with_location syntax_quote(read_form, {})
    end

    def syntax_quote(form, gensyms)
      case form
      when List
        if is_unquote? form
          form.rest.first
        elsif is_unquote_splicing? form
          syntax_error "splicing unquote (~@) not in list"
        else
          cons(CONCAT, syntax_quote_list(form, gensyms))
        end
      when Array
        syntax_quote_coll(:array, form, gensyms)
      when Set
        syntax_quote_coll(:'hash-set', form, gensyms)
      when Hash
        syntax_quote_coll(:hash, form, gensyms)
      when Identifier
        name = form.name

        if name.to_s.end_with?('#')
          gensyms[name] ||= Apricot.gensym(name)
          List[QUOTE, gensyms[name]]
        else
          List[QUOTE, form]
        end
      else
        form
      end
    end

    def syntax_quote_coll(creator_name, elements, gensyms)
      creator = Identifier.intern(creator_name)
      list = cons(CONCAT, syntax_quote_list(elements, gensyms))
      List[APPLY, creator, list]
    end

    def syntax_quote_list(elements, gensyms)
      elements.map do |form|
        if is_unquote? form
          List[LIST, form.rest.first]
        elsif is_unquote_splicing? form
          form.rest.first
        else
          List[LIST, syntax_quote(form, gensyms)]
        end
      end.to_list
    end

    def read_unquote
      unquote_type = UNQUOTE
      next_char # skip the ~

      if @char == '@'
        next_char # skip the ~@
        unquote_type = UNQUOTE_SPLICING
      end

      skip_whitespace

      unless @char
        syntax = (unquote_type == UNQUOTE ? '~' : '~@')
        incomplete_error "Unexpected end of program after #{syntax}, expected a form"
      end

      with_location List[unquote_type, read_form]
    end

    def read_fn
      line = @line

      @fn_state << FnState.new([], nil)
      body = read_list
      state = @fn_state.pop

      state.args << Identifier.intern(:'&') << state.rest if state.rest

      args = state.args.map.with_index do |x, i|
        x || Apricot.gensym("p#{i + 1}")
      end

      with_location List[FN, args, body], line
    end

    def read_list
      next_char # skip the (
      with_location read_forms_until(')').to_list
    end

    def read_array
      next_char # skip the [
      with_location read_forms_until(']')
    end

    def read_hash
      next_char # skip the {
      forms = read_forms_until('}')
      syntax_error "Odd number of forms in key-value hash" if forms.count.odd?
      with_location hashify(forms)
    end

    def read_set
      next_char # skip the {
      with_location read_forms_until('}').to_set
    end

    def read_string
      line = @line
      next_char # skip the opening "
      string = ""

      while @char
        if @char == '"'
          next_char # consume the "
          return with_location string, line
        end

        string << read_string_char
      end

      # Can only reach here if we run out of chars without getting a "
      incomplete_error "Unexpected end of program while parsing string"
    end

    def read_string_char
      char =
        if @char == "\\"
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

    # Read digits in a certain base for string character escapes
    def char_escape_helper(base, regex, n)
      number = ""

      n.times do
        number << @char
        next_char
        break if @char !~ regex
      end

      number.to_i(base).chr
    end

    def read_regex
      line = @line
      next_char # skip the r
      delimiter = opposite_delimiter(@char)
      next_char # skip delimiter
      regex = ""

      while @char
        if @char == delimiter
          next_char # consume delimiter
          options = regex_options_helper
          return with_location Regexp.new(regex, options), line
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

    def read_quotation(double_quote)
      line = @line
      next_char # skip the prefix
      delimiter = opposite_delimiter(@char)
      next_char # skip delimiter
      string = ""

      while @char
        if @char == delimiter
          next_char # consume delimiter
          return with_location string, line
        end

        if double_quote
          string << read_string_char
        elsif @char == "\\" && (peek_char == delimiter || peek_char == "\\")
          next_char
          string << consume_char
        else
          string << consume_char
        end
      end

      incomplete_error "Unexpected end of program while parsing quotation"
    end

    def read_symbol
      line = @line
      next_char # skip the :
      symbol = ""

      if @char == '"'
        next_char # skip opening "
        while @char
          break if @char == '"'
          symbol << read_string_char
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

      symbol.to_sym
    end

    def read_number
      number = ""

      while @char =~ IDENTIFIER
        number << @char
        next_char
      end

      case number
      when /^[+-]?\d+$/
        number.to_i
      when /^([+-]?)(\d+)r([a-zA-Z0-9]+)$/
        sign, radix, digits = $1, $2.to_i, $3
        syntax_error "Radix out of range: #{radix}" unless 2 <= radix && radix <= 36
        syntax_error "Invalid digits for radix in number: #{number}" unless digits.downcase.chars.all? {|d| DIGITS[0..radix-1].include?(d) }
        (sign + digits).to_i(radix)
      when /^[+-]?\d+\.?\d*(?:e[+-]?\d+)?$/
        number.to_f
      when /^([+-]?\d+)\/(\d+)$/
        Rational($1.to_i, $2.to_i)
      else
        syntax_error "Invalid number: #{number}"
      end
    end

    def read_identifier
      identifier = ""

      while @char =~ IDENTIFIER
        identifier << @char
        next_char
      end

      case identifier
      when 'true'  then return true
      when 'false' then return false
      when 'nil'   then return nil
      end

      state = @fn_state.last

      # Handle % identifiers in #() syntax
      if state && identifier[0] == '%'
        case identifier[1..-1]
        when '' # % is equivalent to %1
          state.args[0] ||= with_location Apricot.gensym('p1')
        when '&'
          state.rest ||= with_location Apricot.gensym('rest')
        when /^[1-9]\d*$/
          n = identifier[1..-1].to_i
          state.args[n - 1] ||= with_location Apricot.gensym("p#{n}")
        else
          syntax_error "arg literal must be %, %& or %integer"
        end
      else
        with_location Identifier.intern(identifier)
      end
    end

    def read_pipe_identifier
      line = @line
      next_char # skip the |
      identifier = ""

      while @char
        if @char == '|'
          next_char # consume the |
          return with_location Identifier.intern(identifier)
        end

        identifier << read_string_char
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
      @char
    end

    def peek_char
      char = @io.getc
      return nil unless char
      @io.ungetc char
      char
    end

    def syntax_error(message)
      raise SyntaxError.new(@filename, @line, message)
    end

    def incomplete_error(message)
      raise SyntaxError.new(@filename, @line, message, true)
    end

    def with_location(obj, line = @line)
      obj.apricot_meta = {line: line}
      obj
    end

    def cons(head, tail)
      tail.cons(head)
    end

    def is_unquote?(form)
      form.is_a?(List) && form.first == UNQUOTE
    end

    def is_unquote_splicing?(form)
      form.is_a?(List) && form.first == UNQUOTE_SPLICING
    end

    def hashify(array)
      array.each_slice(2).with_object({}) do |(key, value), hash|
        hash[key] = value
      end
    end

    def opposite_delimiter(c)
      case c
      when '(' then ')'
      when '[' then ']'
      when '{' then '}'
      when '<' then '>'
      else c
      end
    end
  end
end
