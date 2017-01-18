require 'aot_compile_cache'

class AOTCompileCache
  module YAML
    class << self
      attr_accessor :msgpack_factory
    end

    def self.input_to_storage(contents, _)
      obj = ::YAML.load(contents)
      msgpack_factory.packer.write(obj).to_s
    rescue NoMethodError
      # if the object included things that we can't serialize, fall back to
      # Marshal. It's a bit slower, but can encode anything yaml can.
      return Marshal.dump(obj)
    end

    def self.storage_to_output(data)
      msgpack_factory.unpacker.feed(data).read
    rescue MessagePack::MalformedFormatError
      # If it was a Marshal message, it will be invalid MessagePack.  Since
      # this is a rare path, it's probably better to optimistically try
      # MessagePack first. We could, however, check for 0x04, 0x08 at the start
      # of the message, which indicates Marshal format.
      return Marshal.load(data)
    end

    def self.input_to_output(data)
      ::YAML.load(data)
    end

    def self.install!
      require 'yaml'
      require 'msgpack'

      # MessagePack serializes symbols as strings by default.
      # We want them to roundtrip cleanly, so we use a custom factory.
      # see: https://github.com/msgpack/msgpack-ruby/pull/122
      factory = MessagePack::Factory.new
      factory.register_type(0x00, Symbol)
      AOTCompileCache::YAML.msgpack_factory = factory

      klass = class << ::YAML; self; end
      klass.send(:define_method, :load_file) do |path|
        AOTCompileCache::Native.fetch(path.to_s, AOTCompileCache::YAML)
      end
    end
  end
end

AOTCompileCache::YAML.install!
