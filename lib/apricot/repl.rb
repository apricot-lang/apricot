require 'readline'

module Apricot
  class REPL
    # TODO: make history more configurable
    HISTORY_FILE = "~/.apricot-history"
    MAX_HISTORY_LINES = 1000

    COMMANDS = {
      "!backtrace" => [
        "Print the backtrace of the most recent exception",
        proc do
          puts (@exception ? @exception.awesome_backtrace : "No backtrace")
        end
      ],

      "!exit" => ["Exit the REPL", proc { exit }],

      "!help" => [
        "Print this message",
        proc do
          COMMANDS.sort.each {|name, a| puts name.ljust(14) + a[0] }
        end
      ]
    }

    COMPLETIONS = (COMMANDS.keys + SpecialForm::Specials.keys.map(&:to_s)).sort

    def initialize(prompt, bytecode = false, history_file = nil)
      @prompt = prompt
      @bytecode = bytecode
      @history_file = File.expand_path(history_file || HISTORY_FILE)
    end

    def run
      Readline.completion_append_character = " "

      Readline.completion_proc = proc do |s|
        COMPLETIONS.select {|c| c.start_with? s }
      end

      load_history
      terminal_state = `stty -g`.chomp

      while code = readline_with_history
        stripped = code.strip
        if stripped.empty?
          next
        elsif stripped.start_with?('!')
          if COMMANDS.include?(stripped) && block = COMMANDS[stripped][1]
            instance_eval(&block)
          else
            puts "Unknown command: #{stripped}"
          end
          next
        end

        begin
          value = Apricot::Compiler.eval(code, "(eval)", @bytecode)
          puts "=> #{value.apricot_inspect}"
        rescue Exception => e
          @exception = e
          puts "#{e.class}: #{e.message}"
        end
      end

      puts # Print a newline after Ctrl-D (EOF)

    ensure
      save_history
      system('stty', terminal_state) # Restore the terminal
    end

    def load_history
      if File.exist?(@history_file)
        File.open(@history_file) do |f|
          f.each {|line| Readline::HISTORY << line.chomp }
        end
      end
    end

    def save_history
      File.open(@history_file, "w") do |f|
        hist = Readline::HISTORY.to_a
        f.puts(hist[-MAX_HISTORY_LINES..-1] || hist)
      end
    end

    # Smarter Readline to prevent empty and dups
    #   1. Read a line and append to history
    #   2. Quick Break on nil
    #   3. Remove from history if empty or dup
    def readline_with_history
      line = Readline.readline(@prompt, true)
      return if line.nil?

      if line =~ /^\s*$/ or Readline::HISTORY[-2] == line
        Readline::HISTORY.pop
      end

      line
    end
  end
end
