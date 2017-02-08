class << $LOAD_PATH
  alias_method :shovel_without_lpc, :<<
  def <<(entry)
    Bootsnap::LoadPathCache.load_path_cache.add_paths(entry, front: false)
    shovel_without_lpc(entry)
  end

  alias_method :push_without_lpc, :push
  def push(*entries)
    Bootsnap::LoadPathCache.load_path_cache.add_paths(*entries, front: false)
    push_without_lpc(*entries)
  end

  alias_method :unshift_without_lpc, :unshift
  def unshift(*entries)
    Bootsnap::LoadPathCache.load_path_cache.add_paths(*entries, front: true)
    unshift_without_lpc(*entries)
  end

  alias_method :concat_without_lpc, :concat
  def concat(entries)
    Bootsnap::LoadPathCache.load_path_cache.add_paths(*entries, front: false)
    concat_without_lpc(entries)
  end

  # Rails calls `uniq!` on the load path, and we don't prevent it. It's mostly
  # harmless as far as our accounting goes.

  %w(
    collect! map! compact! delete delete_at delete_if fill flatten! insert map!
    reject! reverse! select! shuffle! shift slice! sort! sort_by!
  ).each do |meth|
    define_method(meth) do
      raise NotImplementedError, "destructive method on $LOAD_PATH not supported by Bootsnap: #{meth}"
    end
  end
end

module Kernel
  alias_method :require_without_cache, :require
  def require(path)
    require_without_cache(Bootsnap::LoadPathCache.load_path_cache[path] || path)
  rescue Bootsnap::LoadPathCache::ReturnFalse
    return false
  end

  alias_method :load_without_cache, :load
  def load(path, wrap = false)
    load_without_cache(Bootsnap::LoadPathCache.load_path_cache[path] || path, wrap)
  rescue Bootsnap::LoadPathCache::ReturnFalse
    return false
  end
end

class << Kernel
  alias_method :require_without_cache, :require
  def require(path)
    require_without_cache(Bootsnap::LoadPathCache.load_path_cache[path] || path)
  rescue Bootsnap::LoadPathCache::ReturnFalse
    return false
  end

  alias_method :load_without_cache, :load
  def load(path, wrap = false)
    load_without_cache(Bootsnap::LoadPathCache.load_path_cache[path] || path, wrap)
  rescue Bootsnap::LoadPathCache::ReturnFalse
    return false
  end
end

class Module
  alias_method :autoload_without_cache, :autoload
  def autoload(const, path)
    autoload_without_cache(const, Bootsnap::LoadPathCache.load_path_cache[path] || path)
  rescue Bootsnap::LoadPathCache::ReturnFalse
    return false
  end
end
