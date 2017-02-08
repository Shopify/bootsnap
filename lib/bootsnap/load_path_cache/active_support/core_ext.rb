require 'active_support/dependencies'

class << ActiveSupport::Dependencies.autoload_paths
  alias_method :shovel_without_lpc, :<<
  def <<(entry)
    Bootsnap::LoadPathCache.autoload_path_cache.add_paths(entry, front: false)
    shovel_without_lpc(entry)
  end

  alias_method :push_without_lpc, :push
  def push(*entries)
    Bootsnap::LoadPathCache.autoload_path_cache.add_paths(*entries, front: false)
    push_without_lpc(*entries)
  end

  alias_method :unshift_without_lpc, :unshift
  def unshift(*entries)
    Bootsnap::LoadPathCache.autoload_path_cache.add_paths(*entries, front: true)
    unshift_without_lpc(*entries)
  end

  alias_method :concat_without_lpc, :concat
  def concat(entries)
    Bootsnap::LoadPathCache.autoload_path_cache.add_paths(*entries, front: false)
    concat_without_lpc(entries)
  end

  %w(
    collect! map! compact! delete delete_at delete_if fill flatten! insert map!
    reject! reverse! select! shuffle! shift slice! sort! sort_by! uniq!
  ).each do |meth|
    define_method(meth) do
      raise NotImplementedError,
        "destructive method on ActiveSupport::Dependencies.autoload_paths not supported by Bootsnap: #{meth}"
    end
  end
end

module ActiveSupport
  module Dependencies
    alias_method :search_for_file_without_cache, :search_for_file
    def search_for_file(path)
      Bootsnap::LoadPathCache.autoload_path_cache[path] || search_for_file_without_cache(path)
    rescue ReturnFalse
      nil # doesn't really apply here
    end
  end
end
