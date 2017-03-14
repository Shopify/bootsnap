require 'zlib'

module Bootsnap
  module CompileCache
    class RubyCache
      def initialize(store)
        @cache = store
        compile_option_updated
      end

      def compile_option_updated
        option = RubyVM::InstructionSequence.compile_option
        @compile_option = Zlib.crc32(option.inspect)
      end

      K_VERSION = 0
      K_OS_VERSION = 1
      K_COMPILE_OPTION = 2
      K_RUBY_REVISION = 3
      K_MTIME = 4

      VERSION = 1
      OS_VERSION = `uname -r`.chomp

      def fetch(path) # TODO: do this in a transaction
        cache_key = @cache.get("k:#{path}")
        mtime = File.mtime(path).to_i
        want_key = [VERSION, OS_VERSION, @compile_option, RUBY_REVISION, mtime].join(':')

        if cache_key == want_key
          value = @cache.get("v:#{path}")
          return RubyVM::InstructionSequence.load_from_binary(value)
        end

        iseq = RubyVM::InstructionSequence.compile_file(path)
        @cache.set("k:#{path}", want_key)
        @cache.set("v:#{path}", iseq.to_binary)

        iseq
      end
    end
  end
end
