# frozen_string_literal: true
require('bootsnap/bootsnap')

module Bootsnap
  module CompileCache
    module YAML
      class << self
        attr_accessor(:msgpack_factory, :cache_dir, :supported_options)

        def input_to_storage(contents, _, kwargs)
          raise(Uncompilable) if contents.index("!ruby/object")
          obj = ::YAML.load(contents, **(kwargs || {}))
          msgpack_factory.dump(obj)
        rescue NoMethodError, RangeError
          # if the object included things that we can't serialize, fall back to
          # Marshal. It's a bit slower, but can encode anything yaml can.
          # NoMethodError is unexpected types; RangeError is Bignums
          Marshal.dump(obj)
        end

        def storage_to_output(data, kwargs)
          # This could have a meaning in messagepack, and we're being a little lazy
          # about it. -- but a leading 0x04 would indicate the contents of the YAML
          # is a positive integer, which is rare, to say the least.
          if data[0] == 0x04.chr && data[1] == 0x08.chr
            Marshal.load(data)
          else
            msgpack_factory.load(data, **(kwargs || {}))
          end
        end

        def input_to_output(data, kwargs)
          ::YAML.load(data, **(kwargs || {}))
        end

        def install!(cache_dir)
          self.cache_dir = cache_dir
          init!
          ::YAML.singleton_class.prepend(Patch)
        end

        def init!
          require('yaml')
          require('msgpack')

          # MessagePack serializes symbols as strings by default.
          # We want them to roundtrip cleanly, so we use a custom factory.
          # see: https://github.com/msgpack/msgpack-ruby/pull/122
          factory = MessagePack::Factory.new
          factory.register_type(0x00, Symbol)
          self.msgpack_factory = factory

          self.supported_options = []
          params = ::YAML.method(:load).parameters
          if params.include?([:key, :symbolize_names])
            self.supported_options << :symbolize_names
          end
          if params.include?([:key, :freeze])
            if factory.load(factory.dump('yaml'), freeze: true).frozen?
              self.supported_options << :freeze
            end
          end
          self.supported_options.freeze
        end
      end

      module Patch
        extend self

        def load_file(path, *args)
          return super if args.size > 1
          if kwargs = args.first
            return super unless kwargs.is_a?(Hash)
            return super unless (kwargs.keys - ::Bootsnap::CompileCache::YAML.supported_options).empty?
          end

          begin
            ::Bootsnap::CompileCache::Native.fetch(
              Bootsnap::CompileCache::YAML.cache_dir,
              path,
              ::Bootsnap::CompileCache::YAML,
              kwargs,
            )
          rescue Errno::EACCES
            ::Bootsnap::CompileCache.permission_error(path)
          end
        end
      end
    end
  end
end
