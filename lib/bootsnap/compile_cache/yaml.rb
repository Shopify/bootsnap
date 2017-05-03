module Bootsnap
  module CompileCache
    module YAML
      class << self
        attr_accessor :cache,
          :cache_key,
          :file_key
      end

      self.cache_key = proc do |path|
        require 'digest'
        Digest::MD5.hexdigest(path)
      end

      self.file_key = proc do |path|
        require 'digest'
        Digest::MD5.hexdigest [
          path,
          File.mtime(path).to_i,
          Bootsnap::VERSION
        ].join
      end

      def load_file(path)
        key = YAML.cache_key.call(path)
        yaml, cached_file_key = YAML.cache.get(key)
        file_key = YAML.file_key.call(path)
        unless file_key == cached_file_key
          yaml = super(path)
          YAML.cache.set(key, [yaml, file_key])
        end
        yaml
      end

      def self.install!(cache)
        YAML.cache = cache
        require 'yaml'
        ::YAML.singleton_class.prepend Bootsnap::CompileCache::YAML
      end
    end
  end
end
