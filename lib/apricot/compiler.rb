module Apricot
  class Compiler < Rubinius::Compiler
    def self.compiled_name(file)
      if file.suffix? ".apr"
        file + "c"
      else
        file + ".compiled.aprc"
      end
    end

    def self.compile(file, output = nil, debug = false)
      compiler = new :apricot_file, :compiled_file

      compiler.parser.input file
      compiler.packager.print.bytecode = debug if debug
      compiler.writer.name = output || Rubinius::Compiler.compiled_name(file)

      compiler.run
    end
  end
end
