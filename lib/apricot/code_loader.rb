module Apricot
  def self.load(file)
    CodeLoader.load(file)
  end

  def self.require(file)
    CodeLoader.require(file)
  end

  module CodeLoader
    LOADED_FILES = Set.new
    LOCK = Object.new

    module_function

    def load(path)
      full_path = find_source(path)
      raise LoadError, "no such file to load -- #{path}" unless full_path

      Compiler.compile(full_path)
      true
    end

    def require(path)
      full_path = find_source(path)
      raise LoadError, "no such file to load -- #{path}" unless full_path

      if loaded? full_path
        false
      else
        Compiler.compile(full_path)
        $LOADED_FEATURES << full_path
        true
      end
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
      @stat = File::Stat.stat path
      return false unless @stat
      @stat.file? and @stat.readable?
    end

    def loaded?(path)
      $LOADED_FEATURES.include?(path)
    end
  end
end
