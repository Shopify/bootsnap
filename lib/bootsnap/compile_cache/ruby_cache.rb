require 'zlib'

module Bootsnap
  module CompileCache
    class RubyCache
      K_VERSION = 0
      K_OS_VERSION = 1
      K_COMPILE_OPTION = 2
      K_RUBY_REVISION = 3
      K_MTIME = 4

      VERSION = 1
      OS_VERSION = `uname -r`.chomp

      def initialize(store)
        @cache = store
        compile_option_updated
      end

      def compile_option_updated
        option = RubyVM::InstructionSequence.compile_option
        compile_option = Zlib.crc32(option.inspect)
        @key_prefix = [VERSION, OS_VERSION, RUBY_REVISION, compile_option].join(':') + ':'
      end

      def fetch(path)
        mtime = File.mtime(path).to_i
        want_key = "#{@key_prefix}#{mtime}"

        keyname = "k:#{path}"
        valname = "v:#{path}"

        @cache.transaction(true) do
          cache_key = @cache.get(keyname)

          if cache_key == want_key
            value = @cache.get(valname)
            return RubyVM::InstructionSequence.load_from_binary(value)
          end
        end

        iseq = RubyVM::InstructionSequence.compile_file(path)
        bin = iseq.to_binary

        @cache.transaction(false) do
          @cache.set(keyname, want_key)
          @cache.set(valname, bin)
        end

        iseq
      end
    end
  end
end
