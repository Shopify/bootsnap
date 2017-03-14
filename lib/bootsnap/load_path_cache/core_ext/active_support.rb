require 'active_support/dependencies'

module ActiveSupport
  module Dependencies
    alias_method :search_for_file_without_cache, :search_for_file
    def search_for_file(path)
      if Thread.current[:dependencies_try_harder]
        search_for_file_without_cache(path)
      else
        begin
          BootLib::LoadPathCache.autoload_paths_cache.find(path)
        rescue BootLib::LoadPathCache::ReturnFalse
          nil # doesn't really apply here
        end
      end
    end

    def autoloadable_module?(path_suffix)
      BootLib::LoadPathCache.autoload_paths_cache.has_dir?(path_suffix)
    end

    alias_method :load_missing_constant_without_cache, :load_missing_constant
    def load_missing_constant(from_mod, const_name)
      begin
        load_missing_constant_without_cache(from_mod, const_name)
      rescue NameError
        begin
          Thread.current[:dependencies_try_harder] = true
          load_missing_constant_without_cache(from_mod, const_name)
        ensure
          Thread.current[:dependencies_try_harder] = false
        end
      end
    end
  end
end
