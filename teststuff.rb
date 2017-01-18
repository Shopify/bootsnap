require 'aot_compile_cache'

module Handler
  def self.input_to_storage(_, path)
    RubyVM::InstructionSequence.compile_file(path).to_binary
  rescue SyntaxError
    raise AOTCompileCache::Uncompilable
  end

  def self.storage_to_output(binary)
    RubyVM::InstructionSequence.load_from_binary(binary)
  end

  def self.input_to_output
    nil # ruby handles this
  end
end

path = "/Users/burke/src/github.com/Shopify/shopify/config/environments/development.rb"
data = AOTCompileCache::Native.fetch(path, Handler)

puts data.inspect
