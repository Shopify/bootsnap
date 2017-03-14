module Bootsnap
  module CompileCache
    class << self
      attr_reader :ruby_compile_cache, :yaml_compile_cache

      def setup(cache_path:, ruby: true, yaml: true)
        store = Bootsnap::StringCache.new(cache_path)
        at_exit { store.close unless store.closed? }

        start_ruby_cache(store) if ruby
        start_yaml_cache(store) if yaml
      end

      private

      def start_ruby_cache(store)
        require_relative 'compile_cache/ruby_cache'
        @ruby_compile_cache = RubyCache.new(store)
        require_relative 'compile_cache/core_ext/ruby'
      end

      def start_yaml_cache(store)
        require_relative 'compile_cache/yaml_cache'
        @yaml_compile_cache = YAMLCache.new(store)
        require_relative 'compile_cache/core_ext/yaml'
      end
    end
  end
end
