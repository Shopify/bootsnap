# frozen_string_literal: true
require('bootsnap/bootsnap')

module Bootsnap
  module CompileCache
    module JSON
      class << self
        attr_accessor(:msgpack_factory, :cache_dir, :supported_options)

        def input_to_storage(payload, _)
          obj = ::JSON.parse(payload)
          msgpack_factory.dump(obj)
        end

        def storage_to_output(data, kwargs)
          if kwargs && kwargs.key?(:symbolize_names)
            kwargs[:symbolize_keys] = kwargs.delete(:symbolize_names)
          end
          msgpack_factory.load(data, kwargs)
        end

        def input_to_output(data, kwargs)
          ::JSON.parse(data, **(kwargs || {}))
        end

        def precompile(path, cache_dir: self.cache_dir)
          Bootsnap::CompileCache::Native.precompile(
            cache_dir,
            path.to_s,
            self,
          )
        end

        def install!(cache_dir)
          self.cache_dir = cache_dir
          init!
          if ::JSON.respond_to?(:load_file)
            ::JSON.singleton_class.prepend(Patch)
          end
        end

        def init!
          require('json')
          require('msgpack')

          self.msgpack_factory = MessagePack::Factory.new
          self.supported_options = [:symbolize_names]
          if ::JSON.parse('["foo"]', freeze: true).first.frozen?
            self.supported_options = [:freeze]
          end
          self.supported_options.freeze
        end
      end

      module Patch
        def load_file(path, *args)
          return super if args.size > 1
          if kwargs = args.first
            return super unless kwargs.is_a?(Hash)
            return super unless (kwargs.keys - ::Bootsnap::CompileCache::JSON.supported_options).empty?
          end

          begin
            ::Bootsnap::CompileCache::Native.fetch(
              Bootsnap::CompileCache::JSON.cache_dir,
              File.realpath(path),
              ::Bootsnap::CompileCache::JSON,
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
