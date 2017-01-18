module Bootsnap
  module LoadPathCache
    module CoreExt
      def self.make_load_error(path)
        err = LoadError.new("cannot load such file -- #{path}")
        err.define_singleton_method(:path) { path }
        err
      end
    end
  end
end

module Kernel
  alias_method :require_without_cache, :require
  def require(path)
    if resolved = Bootsnap::LoadPathCache.load_path_cache.find(path)
      require_without_cache(resolved)
    else
      raise Bootsnap::LoadPathCache::CoreExt.make_load_error(path)
    end
  rescue Bootsnap::LoadPathCache::ReturnFalse
    return false
  rescue Bootsnap::LoadPathCache::FallbackScan
    require_without_cache(path)
  end

  alias_method :load_without_cache, :load
  def load(path, wrap = false)
    if resolved = Bootsnap::LoadPathCache.load_path_cache.find(path)
      load_without_cache(resolved, wrap)
    else
      # load also allows relative paths from pwd even when not in $:
      relative = File.expand_path(path)
      if File.exist?(File.expand_path(path))
        return load_without_cache(relative, wrap)
      end
      raise Bootsnap::LoadPathCache::CoreExt.make_load_error(path)
    end
  rescue Bootsnap::LoadPathCache::ReturnFalse
    return false
  rescue Bootsnap::LoadPathCache::FallbackScan
    load_without_cache(path, wrap)
  end
end

class << Kernel
  alias_method :require_without_cache, :require
  def require(path)
    if resolved = Bootsnap::LoadPathCache.load_path_cache.find(path)
      require_without_cache(resolved)
    else
      raise Bootsnap::LoadPathCache::CoreExt.make_load_error(path)
    end
  rescue Bootsnap::LoadPathCache::ReturnFalse
    return false
  rescue Bootsnap::LoadPathCache::FallbackScan
    require_without_cache(path)
  end

  alias_method :load_without_cache, :load
  def load(path, wrap = false)
    if resolved = Bootsnap::LoadPathCache.load_path_cache.find(path)
      load_without_cache(resolved, wrap)
    else
      # load also allows relative paths from pwd even when not in $:
      relative = File.expand_path(path)
      if File.exist?(relative)
        return load_without_cache(relative, wrap)
      end
      raise Bootsnap::LoadPathCache::CoreExt.make_load_error(path)
    end
  rescue Bootsnap::LoadPathCache::ReturnFalse
    return false
  rescue Bootsnap::LoadPathCache::FallbackScan
    load_without_cache(path, wrap)
  end
end

class Module
  alias_method :autoload_without_cache, :autoload
  def autoload(const, path)
    autoload_without_cache(const, Bootsnap::LoadPathCache.load_path_cache.find(path) || path)
  rescue Bootsnap::LoadPathCache::ReturnFalse
    return false
  rescue Bootsnap::LoadPathCache::FallbackScan
    autoload_without_cache(const, path)
  end
end
