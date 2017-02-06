require_relative '../bootsnap'

# We're running here after bundle setup but before we install bootscale.
# Try as hard as possible not to traverse the LOAD_PATH.
begin
  require(RbConfig::CONFIG['rubyarchdir'] + "/zlib." + RbConfig::CONFIG['DLEXT'])
rescue LoadError
  require 'zlib'
end

class BootSnap
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
        STDERR.puts "[BootSnap] warning: rejecting broken binary"
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
        BootSnap::Native.fetch(path.to_s, BootSnap::ISeq)
      end

      def compile_option=(hash)
        super(hash)
        BootSnap::ISeq.compile_option_updated
      end
    end

    def self.compile_option_updated
      option = RubyVM::InstructionSequence.compile_option
      crc = Zlib.crc32(option.inspect)
      BootSnap::Native.compile_option_crc32 = crc
    end

    def self.setup
      BootSnap::ISeq.compile_option_updated
      class << RubyVM::InstructionSequence
        prepend InstructionSequenceMixin
      end
    end
  end
end
