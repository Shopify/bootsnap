module Kernel
  alias_method :require_without_cache, :require
  def require(path)
    require_without_cache(Bootsnap::LoadPathCache.load_path_cache.find(path) || path)
  rescue Bootsnap::LoadPathCache::ReturnFalse
    return false
  end

  alias_method :load_without_cache, :load
  def load(path, wrap = false)
    load_without_cache(Bootsnap::LoadPathCache.load_path_cache.find(path) || path, wrap)
  rescue Bootsnap::LoadPathCache::ReturnFalse
    return false
  end
end

class << Kernel
  alias_method :require_without_cache, :require
  def require(path)
    require_without_cache(Bootsnap::LoadPathCache.load_path_cache.find(path) || path)
  rescue Bootsnap::LoadPathCache::ReturnFalse
    return false
  end

  alias_method :load_without_cache, :load
  def load(path, wrap = false)
    load_without_cache(Bootsnap::LoadPathCache.load_path_cache.find(path) || path, wrap)
  rescue Bootsnap::LoadPathCache::ReturnFalse
    return false
  end
end

class Module
  alias_method :autoload_without_cache, :autoload
  def autoload(const, path)
    autoload_without_cache(const, Bootsnap::LoadPathCache.load_path_cache.find(path) || path)
  rescue Bootsnap::LoadPathCache::ReturnFalse
    return false
  end
end
