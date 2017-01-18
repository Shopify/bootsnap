require 'aot_compile_cache'
require 'zlib'

class AOTCompileCache
  module ISeq
    def self.input_to_storage(_, path)
      RubyVM::InstructionSequence.compile_file(path).to_binary
    rescue SyntaxError
      raise Uncompilable, 'syntax error'
    end

    def self.storage_to_output(binary)
      RubyVM::InstructionSequence.load_from_binary(binary)
    rescue RuntimeError => e
      if e.message == 'broken binary format'
        STDERR.puts "[AOTCompileCache] warning: rejecting broken binary"
        return nil
      else
        raise
      end
    end

    def self.input_to_output(_)
      nil # ruby handles this
    end

    module InstructionSequenceMixin
      def load_iseq(path)
        AOTCompileCache::Native.fetch(path.to_s, AOTCompileCache::ISeq)
      end

      def compile_option=(hash)
        super(hash)
        AOTCompileCache::ISeq.compile_option_updated
      end
    end

    def self.compile_option_updated
      option = RubyVM::InstructionSequence.compile_option
      crc = Zlib.crc32(option.inspect)
      AOTCompileCache::Native.compile_option_crc32 = crc
    end

    def self.install!
      AOTCompileCache::ISeq.compile_option_updated
      class << RubyVM::InstructionSequence
        prepend InstructionSequenceMixin
      end
    end
  end
end

AOTCompileCache::ISeq.install!
