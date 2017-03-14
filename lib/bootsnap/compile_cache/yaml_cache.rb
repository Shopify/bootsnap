# load path caching is set up by now.
require 'msgpack'
require 'yaml'

module Bootsnap
  module CompileCache
    class YAMLCache
      def initialize(store)
        @cache = store

        # MessagePack serializes symbols as strings by default.
        # We want them to roundtrip cleanly, so we use a custom factory.
        # see: https://github.com/msgpack/msgpack-ruby/pull/122
        @msgpack_factory = MessagePack::Factory.new
        @msgpack_factory.register_type(0x00, Symbol)
      end

      K_VERSION = 0
      K_RUBY_REVISION = 1
      K_MTIME = 2

      VERSION = 1

      def input_to_output(data)
        ::YAML.load(data)
      end

      def storage_to_output(data)
        # This could have a meaning in messagepack, and we're being a little lazy
        # about it. -- but a leading 0x04 would indicate the contents of the YAML
        # is a positive integer, which is rare, to say the least.
        if data[0] == 0x04.chr && data[1] == 0x08.chr
          Marshal.load(data)
        else
          @msgpack_factory.unpacker.feed(data).read
        end
      end

      def loaded_to_storage(obj)
        @msgpack_factory.packer.write(obj).to_s
      rescue NoMethodError, RangeError
        # if the object included things that we can't serialize, fall back to
        # Marshal. It's a bit slower, but can encode anything yaml can.
        # NoMethodError is unexpected types; RangeError is Bignums
        return Marshal.dump(obj)
      end

      def fetch(path) # TODO: do this in a transaction
        cache_key = @cache.get("k:#{path}")
        mtime = File.mtime(path).to_i
        want_key = [VERSION, RUBY_REVISION, mtime].join(':')

        if cache_key == want_key
          value = @cache.get("v:#{path}")
          return storage_to_output(value)
        end

        loaded = ::YAML.load(File.read(path))
        storage = loaded_to_storage(loaded)
        @cache.set("k:#{path}", want_key)
        @cache.set("v:#{path}", storage)

        loaded
      end
    end
  end
end
