# frozen_string_literal: true

module Bootsnap
  module LoadPathCache
    module CoreExt
      def self.make_load_error(path)
        err = LoadError.new(+"cannot load such file -- #{path}")
        err.instance_variable_set(Bootsnap::LoadPathCache::ERROR_TAG_IVAR, true)
        err.define_singleton_method(:path) { path }
        err
      end
    end
  end
end

module Kernel
  module_function

  alias_method(:require_without_bootsnap, :require)

  def require(path)
    fallback = false
    string_path = path.to_s
    return false if Bootsnap::LoadPathCache.loaded_features_index.key?(string_path)

    if (resolved = Bootsnap::LoadPathCache.load_path_cache.find(string_path))
      # Note that require registers to $LOADED_FEATURES while load does not.
      ret = require_without_bootsnap(resolved)
      Bootsnap::LoadPathCache.loaded_features_index.register(string_path, resolved)
      return ret
    end

    raise(Bootsnap::LoadPathCache::CoreExt.make_load_error(path))
  rescue LoadError => error
    error.instance_variable_set(Bootsnap::LoadPathCache::ERROR_TAG_IVAR, true)
    raise(error)
  rescue Bootsnap::LoadPathCache::ReturnFalse
    false
  rescue Bootsnap::LoadPathCache::FallbackScan
    fallback = true
  ensure
    # We raise from `ensure` so that any further exception don't have FallbackScan as a cause
    # See: https://github.com/Shopify/bootsnap/issues/250
    if fallback
      if (cursor = Bootsnap::LoadPathCache.loaded_features_index.cursor(string_path))
        ret = require_without_bootsnap(path)
        resolved = Bootsnap::LoadPathCache.loaded_features_index.identify(string_path, cursor)
        Bootsnap::LoadPathCache.loaded_features_index.register(string_path, resolved)
        ret
      else # If we're not given a cursor, it means we don't need to register the path (likely an absolute path)
        require_without_bootsnap(path)
      end
    end
  end

  alias_method(:require_relative_without_bootsnap, :require_relative)
  def require_relative(path)
    location = caller_locations(1..1).first
    realpath = Bootsnap::LoadPathCache.realpath_cache.call(
      location.absolute_path || location.path, path
    )
    require(realpath)
  end

  alias_method(:load_without_bootsnap, :load)
  def load(path, wrap = false)
    if (resolved = Bootsnap::LoadPathCache.load_path_cache.find(path, try_extensions: false))
      load_without_bootsnap(resolved, wrap)
    else
      load_without_bootsnap(path, wrap)
    end
  end
end

class Module
  alias_method(:autoload_without_bootsnap, :autoload)
  def autoload(const, path)
    fallback = false
    # NOTE: This may defeat LoadedFeaturesIndex, but it's not immediately
    # obvious how to make it work. This feels like a pretty niche case, unclear
    # if it will ever burn anyone.
    #
    # The challenge is that we don't control the point at which the entry gets
    # added to $LOADED_FEATURES and won't be able to hook that modification
    # since it's done in C-land.
    autoload_without_bootsnap(const, Bootsnap::LoadPathCache.load_path_cache.find(path) || path)
  rescue LoadError => error
    error.instance_variable_set(Bootsnap::LoadPathCache::ERROR_TAG_IVAR, true)
    raise(error)
  rescue Bootsnap::LoadPathCache::ReturnFalse
    false
  rescue Bootsnap::LoadPathCache::FallbackScan
    fallback = true
  ensure
    # We raise from `ensure` so that any further exception don't have FallbackScan as a cause
    # See: https://github.com/Shopify/bootsnap/issues/250
    if fallback
      autoload_without_bootsnap(const, path)
    end
  end
end
