require 'bootsnap/bootsnap'
require 'bootsnap/cache/fetch_cache'

module Bootsnap
  module CompileCache
    module ISeq
      class Cache < FetchCache
        class << self
          attr_accessor :compile_option
        end

        def self.file_key(path)
          super(path) + [compile_option]
        end
      end

      class << self
        attr_accessor :cache
      end

      module InstructionSequenceMixin
        def load_iseq(path)
          binary = ISeq.cache.fetch(path) do |_, file_path|
            RubyVM::InstructionSequence.compile_file(file_path).to_binary
          end
          RubyVM::InstructionSequence.load_from_binary(binary)
        rescue RuntimeError => e
          if e.message == 'broken binary format'
            STDERR.puts "[Bootsnap::CompileCache] warning: rejecting broken binary"
            return nil
          else
            raise
          end
        end

        def compile_option=(hash)
          super(hash)
          Bootsnap::CompileCache::ISeq.compile_option_updated
        end
      end

      def self.compile_option_updated
        Cache.compile_option = RubyVM::InstructionSequence.compile_option.inspect
      end

      def self.install!(cache = nil)
        self.cache = Cache.new(cache)
        Bootsnap::CompileCache::ISeq.compile_option_updated
        class << RubyVM::InstructionSequence
          prepend InstructionSequenceMixin
        end
      end
    end
  end
end
