require 'readline'

module Apricot
  class REPL
    # TODO: make history more configurable
    HISTORY_FILE = "~/.apricot-history"
    MAX_HISTORY_LINES = 1000

    COMPLETIONS = SpecialForm::Specials.keys.map(&:to_s).sort

    def initialize(prompt, bytecode = false, history_file = nil)
      @prompt = prompt
      @bytecode = bytecode
      @history_file = File.expand_path(history_file || HISTORY_FILE)
    end

    # TODO: add !backtrace doing the following, also !exit and !help
    # puts (@exception ? @exception.backtrace : "No backtrace")

    def run
      Readline.completion_append_character = " "

      Readline.completion_proc = proc do |s|
        COMPLETIONS.select {|c| c.start_with? s }
      end

      load_history
      terminal_state = `stty -g`.chomp

      loop do
        begin
          code = readline_with_history
          break unless code
          next if code.strip.empty?

          cm = Apricot::Compiler.compile_string code, "(eval)", @bytecode
          value = Rubinius.run_script(cm)
          puts "=> #{value.apricot_inspect}"
        rescue Exception => e
#          @exception = e
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
