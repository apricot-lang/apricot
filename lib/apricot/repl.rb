require 'readline'
require 'yaml'
Apricot.require "repl"

module Apricot
  class REPL
    # TODO: make history more configurable
    HISTORY_FILE = "~/.apricot-history"
    MAX_HISTORY_LINES = 1000

    COMMANDS = {
      "!backtrace" => {
        doc: "Print the backtrace of the most recent exception",
        code: proc do
          puts (@exception ? @exception.awesome_backtrace : "No backtrace")
        end
      },

      "!bytecode" => {
        doc: "Print the bytecode generated from the previous line",
        code: proc do
          puts (@compiled_code ? @compiled_code.decode : "No previous line")
        end
      },

      "!exit" => {doc: "Exit the REPL", code: proc { exit }},

      "!help" => {
        doc: "Print this message",
        code: proc do
          width = 14

          puts "(doc foo)".ljust(width) +
            "Print the documentation for a function or macro"
          COMMANDS.sort.each {|name, c| puts name.ljust(width) + c[:doc] }
        end
      }
    }

    COMMAND_COMPLETIONS = COMMANDS.keys.sort
    SPECIAL_COMPLETIONS = SpecialForm::SPECIAL_FORMS.keys.map(&:to_s)

    def initialize(prompt = 'apr> ', history_file = nil)
      @prompt = prompt
      @history_file = File.expand_path(history_file || HISTORY_FILE)
      @line = 1
    end

    def run
      # *1, *2, and *3 shall hold the results of the previous three
      # evaluations.
      Apricot::Core.set_var(:'*1', nil)
      Apricot::Core.set_var(:'*2', nil)
      Apricot::Core.set_var(:'*3', nil)

      # Set up some Readline options.
      Readline.completion_append_character = " "
      Readline.basic_word_break_characters = " \t\n\"'`~@;{[("

      # Set up tab completion.
      Readline.completion_proc = proc do |s|
        if s.start_with? '!'
          # User is typing a REPL command
          COMMAND_COMPLETIONS.select {|c| c.start_with? s }
        elsif ('A'..'Z').include? s[0]
          # User is typing a constant
          constant_completion(s)
        else
          # User is typing a regular name
          comps = SPECIAL_COMPLETIONS +
            Apricot.current_namespace.vars.keys.map(&:to_s)
          comps.select {|c| c.start_with? s }.sort
        end
      end

      load_history
      terminal_state = `stty -g`.chomp

      # Clear the current line before starting the REPL. This means the user
      # can begin typing before the prompt appears and it will gracefully
      # appear in front of their code when the REPL is ready, without any ugly
      # text duplication issues.
      clear_line

      while code = readline_with_history
        stripped = code.strip

        # Ignore blank lines.
        next if stripped.empty?

        # Handle REPL commands.
        if stripped.start_with?('!')
          if COMMANDS.include?(stripped) && block = COMMANDS[stripped][:code]
            instance_eval(&block)
          else
            puts "Unknown command: #{stripped}"
          end

          next
        end

        # Otherwise treat the input as code to evaluate.
        begin
          begin
            nodes = Apricot::Reader.read_string(code, "(eval)", @line).map {|v| AST::Node.from_value(v, @line) }
          rescue Apricot::SyntaxError => e
            # Reraise unless this is an incomplete error (meaning we can read
            # more on the next line).
            raise unless e.incomplete?

            begin
              indent = ' ' * @prompt.length
              more_code = Readline.readline(indent, false)

              if more_code
                code << "\n" << indent << more_code
                Readline::HISTORY.pop
                Readline::HISTORY << code
                retry
              else
                print "\r" # print the exception at the start of the line
                raise
              end
            rescue Interrupt
              # This is raised by Ctrl-C. Stop trying to read more code and
              # just give up. Remove the current input from history.
              puts "^C"
              current_code = Readline::HISTORY.pop
              @line -= current_code.count("\n")
              next
            end
          end

          nodes.each do |node|
            @compiled_code =
              Apricot::Compiler.compile_node(node, "(eval)", @line)

            value = Rubinius.run_script(@compiled_code)
            puts "=> #{value.apricot_inspect}"

            # Save the result of the evaluation in *1 and shift down the older
            # previous values.
            old   = Apricot::Core.get_var(:'*1')
            older = Apricot::Core.get_var(:'*2')
            Apricot::Core.set_var(:'*1', value)
            Apricot::Core.set_var(:'*2', old)
            Apricot::Core.set_var(:'*3', older)
          end

          e = nil
        rescue Interrupt => e
          # Raised by Ctrl-C. Print a newline so the error message is on the
          # next line.
          puts
        rescue SystemExit, SignalException
          raise
        rescue Exception => e
        end

        if e
          @exception = e
          puts "#{e.class}: #{e.message}"
        end

        @line += 1 + code.count("\n")
      end

      puts # Print a newline after Ctrl-D (EOF)

    ensure
      save_history
      system('stty', terminal_state) if terminal_state # Restore the terminal
    end

    # Clear the current line in the terminal. This snippet was stolen from
    # Pry.
    def clear_line
      puts "\e[0A\e[0G"
    end

    def load_history
      if File.exist?(@history_file)
        hist = YAML.load_file @history_file

        if hist.is_a? Array
          hist.each {|x| Readline::HISTORY << x }
        else
          File.open(@history_file) do |f|
            f.each {|line| Readline::HISTORY << line.chomp }
          end
        end
      end
    end

    def save_history
      return if Readline::HISTORY.empty?

      File.open(@history_file, "w") do |f|
        hist = Readline::HISTORY.to_a
        hist.shift(hist.size - MAX_HISTORY_LINES) if hist.size > MAX_HISTORY_LINES
        YAML.dump(hist, f, header: true)
      end
    end

    # Smarter Readline to prevent empty and dups
    #   1. Read a line and append to history
    #   2. Quick Break on nil
    #   3. Remove from history if empty or dup
    def readline_with_history
      line = Readline.readline(@prompt, true)
      return nil if line.nil?

      if line =~ /\A\s*\z/ || (Readline::HISTORY.size > 1 &&
                             Readline::HISTORY[-2] == line)
        Readline::HISTORY.pop
      end

      line
    rescue Interrupt
      # This is raised by Ctrl-C. Try to read another line.
      puts "^C"
      @line -= 1
      retry
    end

    # Find constant Foo::Bar::Baz from ["Foo", "Bar", "Baz"] array. Helper for
    # tab-completion of constants.
    def find_constant(const_names)
      const_names.reduce(Object) do |mod, name|
        mod.const_get(name)
      end
    rescue NameError
      # Return nil if the constant doesn't exist.
      nil
    end

    # Tab-completion for constants and namespaced identifiers
    def constant_completion(s)
      # Split Foo/bar into Foo and bar. If there is no / then id will be nil.
      constant_str, id = s.split('/', 2)

      # If we have a Foo/bar case, complete the 'bar' part if possible.
      if id
        # Split with -1 returns an extra empty string if constant_str ends in
        # '::'. Then it will fail to find the constant for Foo::/ and we won't
        # try completing Foo::/ to Foo/whatever.
        const_names = constant_str.split('::', -1)

        const = find_constant(const_names)

        # If we can't find the constant the user is typing, don't return any
        # completions. If it isn't a Module or Namespace (subclass of Module),
        # we can't complete methods or vars below it. (e.g. in Math::PI/<tab>
        # we can't do any completions)
        return [] unless const && const.is_a?(Module)

        # Complete the vars of the namespace or the methods of the module.
        potential_completions =
          const.is_a?(Apricot::Namespace) ? const.vars.keys : const.methods

        # Select the matching vars or methods and format them properly as
        # completions.
        potential_completions.select do |c|
          c.to_s.start_with? id
        end.sort.map do |c|
          "#{constant_str}/#{c}"
        end

      # Otherwise there is no / and we complete constant names.
      else
        # Split with -1 returns an extra empty string if constant_str ends in
        # '::'. This allows us to differentiate Foo:: and Foo cases.
        const_names = constant_str.split('::', -1)
        curr_name = const_names.pop # The user is currently typing the last name.

        const = find_constant(const_names)

        # If we can't find the constant the user is typing, don't return any
        # completions. If it isn't a Module, we can't complete constants below
        # it. (e.g. in Math::PI::<tab> we can't do anything)
        return [] unless const && const.is_a?(Module)

        # Select the matching constants and format them properly as
        # completions.
        const.constants.select do |c|
          c.to_s.start_with? curr_name
        end.sort.map do |name|
          if const_names.size == 0
            name.to_s
          else
            "#{const_names.join('::')}::#{name}"
          end
        end
      end
    end
  end
end
