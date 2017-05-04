module Bootsnap
  module CompileCache
    module ISeq
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
          RubyVM::InstructionSequence.compile_option,
          RUBY_VERSION,
          Bootsnap::VERSION
        ].join
      end

      def load_iseq(path)
        key = ISeq.cache_key.call(path).to_s
        binary, cached_file_key = ISeq.cache.get(key)
        file_key = ISeq.file_key.call(path)
        if file_key == cached_file_key
          RubyVM::InstructionSequence.load_from_binary(binary)
        else
          RubyVM::InstructionSequence.compile_file(path).tap do |iseq|
            ISeq.cache.set(key, [iseq.to_binary, file_key])
          end
        end
      rescue => e
        STDERR.puts "[Bootsnap::CompileCache] couldn't load: #{path}, #{e}"
        nil
      end

      def self.install!(cache)
        self.cache = cache
        RubyVM::InstructionSequence.singleton_class.prepend Bootsnap::CompileCache::ISeq
      end
    end
  end
end
