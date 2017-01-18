require 'aot_compile_cache'

class AOTCompileCache
  class YAML < AOTCompileCache
    def self.input_to_storage(contents, _)
      obj = ::YAML.load(contents)
      Marshal.dump(obj)
    end

    def self.storage_to_output(data)
      Marshal.load(data)
    end

    def self.input_to_output(data)
      ::YAML.load(data)
    end

    def self.install!
      require 'yaml'
      klass = class << ::YAML; self; end
      klass.send(:define_method, :load_file) do |path|
        AOTCompileCache::YAML.fetch(path)
      end
    end
  end
end

AOTCompileCache::YAML.install!
