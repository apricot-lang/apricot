module Apricot
  def self.load(file)
    CodeLoader.load(file)
  end

  def self.require(file)
    CodeLoader.require(file)
  end

  module CodeLoader
    module_function

    LOADED_APR_FILES = []

    def load(path)
      full_path = find_source(path)
      raise LoadError, "no such file to load -- #{path}" unless full_path

      load_file full_path
      true
    end

    def require(path)
      full_path = find_source(path)
      raise LoadError, "no such file to load -- #{path}" unless full_path

      if loaded? full_path
        false
      else
        load_file full_path
        $LOADED_FEATURES << full_path
        LOADED_APR_FILES << full_path
        true
      end
    end

    # Check if the second file is newer than the first.
    def file_newer?(path, compiled_name)
      stat = File::Stat.stat(path)
      compiled_stat = File::Stat.stat(compiled_name)

      stat && compiled_stat && stat.mtime < compiled_stat.mtime
    end

    # Check that none of the dependencies of the compiled code have changed
    # since it was compiled.
    def dependencies_unchanged?(compiled_code, path)
      deps = compiled_code.get_metadata(:dependencies)
      return false unless deps.is_a?(String)
      dep_paths = deps.split(File::PATH_SEPARATOR)
      dep_paths.all? {|dep| file_newer?(dep, path) }
    end

    def load_file(path)
      compiled_name = Rubinius::ToolSet::Runtime::Compiler.compiled_name(path)

      # Try to load the cached bytecode if it exists and is newer than the
      # source file and dependencies.
      if file_newer?(path, compiled_name)
        begin
          compiled_name = Rubinius::ToolSet::Runtime::Compiler.compiled_name(path)

          code = Rubinius.invoke_primitive :compiledfile_load, compiled_name,
            Rubinius::Signature, Rubinius::RUBY_LIB_VERSION

          usable = dependencies_unchanged?(code, compiled_name)
        rescue Rubinius::Internal
          usable = false
        end

        if usable
          Rubinius.run_script code
          return
        end
      end

      Compiler.compile_and_eval_file path
    end

    def find_source(path)
      path += ".apr" unless has_extension? path
      path = File.expand_path path if home_path? path

      if qualified_path? path
        if loadable? path
          path
        else
          false
        end
      else
        search_load_path path
      end
    end

    def search_load_path(path)
      $LOAD_PATH.each do |dir|
        full_path = "#{dir}/#{path}"
        return full_path if loadable? full_path
      end

      false
    end

    def has_extension?(path)
      !File.extname(path).empty?
    end

    def home_path?(path)
      path[0] == '~'
    end

    def qualified_path?(path)
      # TODO: fix for Windows
      path[0] == '/' || path.prefix?("./") || path.prefix?("../")
    end

    # Returns true if the path exists, is a regular file, and is readable.
    def loadable?(path)
      stat = File::Stat.stat path
      stat && stat.file? && stat.readable?
    end

    def loaded?(path)
      $LOADED_FEATURES.include?(path)
    end
  end
end
