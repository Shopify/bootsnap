require 'aot_compile_cache'

class AOTCompileCache
  class ISeq < AOTCompileCache
    def self.input_to_storage(_, path)
      RubyVM::InstructionSequence.compile_file(path).to_binary
    rescue SyntaxError
      raise Uncompileable, 'syntax error'
    end

    def self.storage_to_output(binary)
      RubyVM::InstructionSequence.load_from_binary(binary)
    end

    def self.input_to_output
      nil # ruby handles this
    end

    def self.install!
      klass = class << RubyVM::InstructionSequence; self; end
      klass.send(:define_method, :load_iseq) do |srcfile|
        AOTCompileCache::ISeq.fetch(srcfile)
      end
    end
  end
end

AOTCompileCache::ISeq.install!
