# frozen_string_literal: true

module Kernel
  module_function

  alias_method(:require_without_bootsnap, :require)

  def require(path)
    string_path = Bootsnap.rb_get_path(path)
    return false if Bootsnap::LoadPathCache.loaded_features_index.key?(string_path)

    resolved = Bootsnap::LoadPathCache.load_path_cache.find(string_path)
    if Bootsnap::LoadPathCache::FALLBACK_SCAN.equal?(resolved)
      if (cursor = Bootsnap::LoadPathCache.loaded_features_index.cursor(string_path))
        ret = require_without_bootsnap(path)
        resolved = Bootsnap::LoadPathCache.loaded_features_index.identify(string_path, cursor)
        Bootsnap::LoadPathCache.loaded_features_index.register(string_path, resolved)
        return ret
      else
        return require_without_bootsnap(path)
      end
    elsif false == resolved
      return false
    elsif resolved.nil?
      error = LoadError.new(+"cannot load such file -- #{path}")
      error.instance_variable_set(:@path, path)
      raise error
    else
      # Note that require registers to $LOADED_FEATURES while load does not.
      ret = require_without_bootsnap(resolved)
      Bootsnap::LoadPathCache.loaded_features_index.register(string_path, resolved)
      return ret
    end
  end

  alias_method(:load_without_bootsnap, :load)
  def load(path, wrap = false)
    if (resolved = Bootsnap::LoadPathCache.load_path_cache.find(Bootsnap.rb_get_path(path), try_extensions: false))
      load_without_bootsnap(resolved, wrap)
    else
      load_without_bootsnap(path, wrap)
    end
  end
end

class Module
  alias_method(:autoload_without_bootsnap, :autoload)
  def autoload(const, path)
    # NOTE: This may defeat LoadedFeaturesIndex, but it's not immediately
    # obvious how to make it work. This feels like a pretty niche case, unclear
    # if it will ever burn anyone.
    #
    # The challenge is that we don't control the point at which the entry gets
    # added to $LOADED_FEATURES and won't be able to hook that modification
    # since it's done in C-land.
    resolved = Bootsnap::LoadPathCache.load_path_cache.find(Bootsnap.rb_get_path(path))
    if Bootsnap::LoadPathCache::FALLBACK_SCAN.equal?(resolved)
      autoload_without_bootsnap(const, path)
    elsif resolved == false
      return false
    else
      autoload_without_bootsnap(const, resolved || path)
    end
  end
end
