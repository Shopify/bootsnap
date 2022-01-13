# frozen_string_literal: true

require("bootsnap/bootsnap")

module Bootsnap
  module CompileCache
    module YAML
      UnsupportedTags = Class.new(StandardError)

      class << self
        attr_accessor(:msgpack_factory, :supported_options)
        attr_reader(:implementation, :cache_dir)

        def cache_dir=(cache_dir)
          @cache_dir = cache_dir.end_with?("/") ? "#{cache_dir}yaml" : "#{cache_dir}-yaml"
        end

        def precompile(path)
          Bootsnap::CompileCache::Native.precompile(
            cache_dir,
            path.to_s,
            @implementation,
          )
        end

        def install!(cache_dir)
          self.cache_dir = cache_dir
          init!
          ::YAML.singleton_class.prepend(@implementation::Patch)
        end

        def init!
          require("yaml")
          require("msgpack")
          require("date")

          @implementation = ::YAML::VERSION >= "4" ? Psych4 : Psych3
          if @implementation::Patch.method_defined?(:unsafe_load_file) && !::YAML.respond_to?(:unsafe_load_file)
            @implementation::Patch.send(:remove_method, :unsafe_load_file)
          end

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
              unpacker: MessagePack::Time::Unpacker,
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
            supported_options << :symbolize_names
          end
          if params.include?([:key, :freeze])
            if factory.load(factory.dump("yaml"), freeze: true).frozen?
              supported_options << :freeze
            end
          end
          supported_options.freeze
        end

        def patch
          @implementation::Patch
        end

        def strict_load(payload)
          ast = ::YAML.parse(payload)
          return ast unless ast

          strict_visitor.create.visit(ast)
        end

        def strict_visitor
          self::NoTagsVisitor ||= Class.new(Psych::Visitors::ToRuby) do
            def visit(target)
              if target.tag
                raise UnsupportedTags, "YAML tags are not supported: #{target.tag}"
              end

              super
            end
          end
        end
      end

      module Psych4
        extend self

        def input_to_storage(contents, _)
          obj = SafeLoad.input_to_storage(contents, nil)
          if UNCOMPILABLE.equal?(obj)
            obj = UnsafeLoad.input_to_storage(contents, nil)
          end
          obj
        end

        module UnsafeLoad
          extend self

          def input_to_storage(contents, _)
            obj = CompileCache::YAML.strict_load(contents)
            packer = CompileCache::YAML.msgpack_factory.packer
            packer.pack(false) # not safe loaded
            packer.pack(obj)
            packer.to_s
          rescue NoMethodError, RangeError, UnsupportedTags
            UNCOMPILABLE # The object included things that we can't serialize
          end

          def storage_to_output(data, kwargs)
            if kwargs&.key?(:symbolize_names)
              kwargs[:symbolize_keys] = kwargs.delete(:symbolize_names)
            end

            unpacker = CompileCache::YAML.msgpack_factory.unpacker(kwargs)
            unpacker.feed(data)
            _safe_loaded = unpacker.unpack
            unpacker.unpack
          end

          def input_to_output(data, kwargs)
            ::YAML.unsafe_load(data, **(kwargs || {}))
          end
        end

        module SafeLoad
          extend self

          def input_to_storage(contents, _)
            obj = ::YAML.load(contents)
            packer = CompileCache::YAML.msgpack_factory.packer
            packer.pack(true) # safe loaded
            packer.pack(obj)
            packer.to_s
          rescue NoMethodError, RangeError, Psych::DisallowedClass, Psych::BadAlias
            UNCOMPILABLE # The object included things that we can't serialize
          end

          def storage_to_output(data, kwargs)
            if kwargs&.key?(:symbolize_names)
              kwargs[:symbolize_keys] = kwargs.delete(:symbolize_names)
            end

            unpacker = CompileCache::YAML.msgpack_factory.unpacker(kwargs)
            unpacker.feed(data)
            safe_loaded = unpacker.unpack
            if safe_loaded
              unpacker.unpack
            else
              UNCOMPILABLE
            end
          end

          def input_to_output(data, kwargs)
            ::YAML.load(data, **(kwargs || {}))
          end
        end

        module Patch
          def load_file(path, *args)
            return super if args.size > 1

            if (kwargs = args.first)
              return super unless kwargs.is_a?(Hash)
              return super unless (kwargs.keys - ::Bootsnap::CompileCache::YAML.supported_options).empty?
            end

            begin
              ::Bootsnap::CompileCache::Native.fetch(
                Bootsnap::CompileCache::YAML.cache_dir,
                File.realpath(path),
                ::Bootsnap::CompileCache::YAML::Psych4::SafeLoad,
                kwargs,
              )
            rescue Errno::EACCES
              ::Bootsnap::CompileCache.permission_error(path)
            end
          end

          ruby2_keywords :load_file if respond_to?(:ruby2_keywords, true)

          def unsafe_load_file(path, *args)
            return super if args.size > 1

            if (kwargs = args.first)
              return super unless kwargs.is_a?(Hash)
              return super unless (kwargs.keys - ::Bootsnap::CompileCache::YAML.supported_options).empty?
            end

            begin
              ::Bootsnap::CompileCache::Native.fetch(
                Bootsnap::CompileCache::YAML.cache_dir,
                File.realpath(path),
                ::Bootsnap::CompileCache::YAML::Psych4::UnsafeLoad,
                kwargs,
              )
            rescue Errno::EACCES
              ::Bootsnap::CompileCache.permission_error(path)
            end
          end

          ruby2_keywords :unsafe_load_file if respond_to?(:ruby2_keywords, true)
        end
      end

      module Psych3
        extend self

        def input_to_storage(contents, _)
          obj = CompileCache::YAML.strict_load(contents)
          packer = CompileCache::YAML.msgpack_factory.packer
          packer.pack(false) # not safe loaded
          packer.pack(obj)
          packer.to_s
        rescue NoMethodError, RangeError, UnsupportedTags
          UNCOMPILABLE # The object included things that we can't serialize
        end

        def storage_to_output(data, kwargs)
          if kwargs&.key?(:symbolize_names)
            kwargs[:symbolize_keys] = kwargs.delete(:symbolize_names)
          end
          unpacker = CompileCache::YAML.msgpack_factory.unpacker(kwargs)
          unpacker.feed(data)
          _safe_loaded = unpacker.unpack
          unpacker.unpack
        end

        def input_to_output(data, kwargs)
          ::YAML.load(data, **(kwargs || {}))
        end

        module Patch
          def load_file(path, *args)
            return super if args.size > 1

            if (kwargs = args.first)
              return super unless kwargs.is_a?(Hash)
              return super unless (kwargs.keys - ::Bootsnap::CompileCache::YAML.supported_options).empty?
            end

            begin
              ::Bootsnap::CompileCache::Native.fetch(
                Bootsnap::CompileCache::YAML.cache_dir,
                File.realpath(path),
                ::Bootsnap::CompileCache::YAML::Psych3,
                kwargs,
              )
            rescue Errno::EACCES
              ::Bootsnap::CompileCache.permission_error(path)
            end
          end

          ruby2_keywords :load_file if respond_to?(:ruby2_keywords, true)

          def unsafe_load_file(path, *args)
            return super if args.size > 1

            if (kwargs = args.first)
              return super unless kwargs.is_a?(Hash)
              return super unless (kwargs.keys - ::Bootsnap::CompileCache::YAML.supported_options).empty?
            end

            begin
              ::Bootsnap::CompileCache::Native.fetch(
                Bootsnap::CompileCache::YAML.cache_dir,
                File.realpath(path),
                ::Bootsnap::CompileCache::YAML::Psych3,
                kwargs,
              )
            rescue Errno::EACCES
              ::Bootsnap::CompileCache.permission_error(path)
            end
          end

          ruby2_keywords :unsafe_load_file if respond_to?(:ruby2_keywords, true)
        end
      end
    end
  end
end
