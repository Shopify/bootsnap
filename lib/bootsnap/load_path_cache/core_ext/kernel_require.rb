# frozen_string_literal: true

module Bootsnap
  module LoadPathCache
    module CoreExt
      def self.make_load_error(path)
        err = LoadError.new(+"cannot load such file -- #{path}")
        err.instance_variable_set(ERROR_TAG_IVAR, true)
        err.define_singleton_method(:path) { path }
        err
      end

      module Kernel
        def require(path)
          string_path = Bootsnap.rb_get_path(path)
          return false if LoadPathCache.loaded_features_index.key?(string_path)

          resolved = LoadPathCache.load_path_cache.find(string_path)
          if LoadPathCache::FALLBACK_SCAN.equal?(resolved)
            if (cursor = LoadPathCache.loaded_features_index.cursor(string_path))
              ret = super(path)
              resolved = LoadPathCache.loaded_features_index.identify(string_path, cursor)
              LoadPathCache.loaded_features_index.register(string_path, resolved)
              return ret
            else
              return super(path)
            end
          elsif false == resolved
            return false
          elsif resolved.nil?
            error = LoadError.new(+"cannot load such file -- #{path}")
            error.instance_variable_set(:@path, path)
            raise error
          else
            # Note that require registers to $LOADED_FEATURES while load does not.
            ret = super(resolved)
            LoadPathCache.loaded_features_index.register(string_path, resolved)
            return ret
          end
        end

        def load(path, wrap = false)
          if (resolved = LoadPathCache.load_path_cache.find(Bootsnap.rb_get_path(path), try_extensions: false))
            super(resolved, wrap)
          else
            super(path, wrap)
          end
        end
      end

      module Module
        def autoload(const, path)
          # NOTE: This may defeat LoadedFeaturesIndex, but it's not immediately
          # obvious how to make it work. This feels like a pretty niche case, unclear
          # if it will ever burn anyone.
          #
          # The challenge is that we don't control the point at which the entry gets
          # added to $LOADED_FEATURES and won't be able to hook that modification
          # since it's done in C-land.
          resolved = LoadPathCache.load_path_cache.find(Bootsnap.rb_get_path(path))
          if LoadPathCache::FALLBACK_SCAN.equal?(resolved)
            super(const, path)
          elsif resolved == false
            return false
          else
            super(const, resolved || path)
          end
        end
      end
    end

    ::Kernel.prepend(CoreExt::Kernel)
    ::Kernel.singleton_class.prepend(CoreExt::Kernel)
    ::Module.prepend(CoreExt::Module)
  end
end
