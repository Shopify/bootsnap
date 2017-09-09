module Bootsnap
  module CompileCache
    class DefaultPreprocessor
      def call(contents, path)
        contents
      end
    end

    def self.setup(cache_dir:, iseq:, yaml:, preprocessor: nil)
      if preprocessor && !preprocessor.respond_to?(:call)
        raise ArgumentError, 'Invalid preprocessor, must respond to #call'
      end
      preprocessor ||= DefaultPreprocessor.new

      if iseq
        require_relative 'compile_cache/iseq'
        Bootsnap::CompileCache::ISeq.install!(cache_dir, preprocessor)
      end

      if yaml
        require_relative 'compile_cache/yaml'
        Bootsnap::CompileCache::YAML.install!(cache_dir, preprecessor)
      end
    end
  end
end
