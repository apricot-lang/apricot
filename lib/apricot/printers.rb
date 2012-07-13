module Apricot
  class Compiler
    class BytecodePrinter < Rubinius::Compiler::Printer
      def run
        puts @input.decode

        @output = @input
        run_next
      end
    end
  end
end
