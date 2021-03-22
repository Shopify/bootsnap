# frozen_string_literal: true
require('bootsnap/bootsnap')

module Bootsnap
  module CompileCache
    module YAML
      class << self
        attr_accessor(:msgpack_factory, :cache_dir, :supported_options)

        def input_to_storage(contents, _)
          obj = strict_load(contents)
          msgpack_factory.dump(obj)
        rescue NoMethodError, RangeError
          # The object included things that we can't serialize
          raise(Uncompilable)
        end

        def storage_to_output(data, kwargs)
          if kwargs && kwargs.key?(:symbolize_names)
            kwargs[:symbolize_keys] = kwargs.delete(:symbolize_names)
          end
          msgpack_factory.load(data, kwargs)
        end

        def input_to_output(data, kwargs)
          ::YAML.load(data, **(kwargs || {}))
        end

        def strict_load(payload, *args)
          ast = ::YAML.parse(payload)
          return ast unless ast
          strict_visitor.create(*args).visit(ast)
        end
        ruby2_keywords :strict_load if respond_to?(:ruby2_keywords, true)

        def precompile(path, cache_dir: YAML.cache_dir)
          Bootsnap::CompileCache::Native.precompile(
            cache_dir,
            path.to_s,
            Bootsnap::CompileCache::YAML,
          )
        end

        def install!(cache_dir)
          self.cache_dir = cache_dir
          init!
          ::YAML.singleton_class.prepend(Patch)
        end

        def init!
          require('yaml')
          require('msgpack')
          require('date')

          # MessagePack serializes symbols as strings by default.
          # We want them to roundtrip cleanly, so we use a custom factory.
          # see: https://github.com/msgpack/msgpack-ruby/pull/122
          factory = MessagePack::Factory.new
          factory.register_type(0x00, Symbol)

          if defined? MessagePack::Timestamp
            factory.register_type(
              MessagePack::Timestamp::TYPE, # or just -1
              Time,
              packer: MessagePack::Time::Packer,
              unpacker: MessagePack::Time::Unpacker
            )

            marshal_fallback = {
              packer: ->(value) { Marshal.dump(value) },
              unpacker: ->(payload) { Marshal.load(payload) },
            }
            {
              Date => 0x01,
              Regexp => 0x02,
            }.each do |type, code|
              factory.register_type(code, type, marshal_fallback)
            end
          end

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

        def strict_visitor
          self::NoTagsVisitor ||= Class.new(Psych::Visitors::ToRuby) do
            def visit(target)
              if target.tag
                raise Uncompilable, "YAML tags are not supported: #{target.tag}"
              end
              super
            end
          end
        end
      end

      module Patch
        def load_file(path, *args)
          return super if args.size > 1
          if kwargs = args.first
            return super unless kwargs.is_a?(Hash)
            return super unless (kwargs.keys - ::Bootsnap::CompileCache::YAML.supported_options).empty?
          end

          begin
            ::Bootsnap::CompileCache::Native.fetch(
              Bootsnap::CompileCache::YAML.cache_dir,
              File.realpath(path),
              ::Bootsnap::CompileCache::YAML,
              kwargs,
            )
          rescue Errno::EACCES
            ::Bootsnap::CompileCache.permission_error(path)
          end
        end

        ruby2_keywords :load_file if respond_to?(:ruby2_keywords, true)
      end
    end
  end
end
