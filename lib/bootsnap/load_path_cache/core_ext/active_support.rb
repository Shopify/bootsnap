module ActiveSupport
  module Dependencies
    alias_method :search_for_file_without_cache, :search_for_file
    def search_for_file(path)
      if Thread.current[:dependencies_try_harder]
        search_for_file_without_cache(path)
      else
        begin
          Bootsnap::LoadPathCache.autoload_paths_cache.find(path)
        rescue Bootsnap::LoadPathCache::ReturnFalse
          nil # doesn't really apply here
        end
      end
    end

    def autoloadable_module?(path_suffix)
      Bootsnap::LoadPathCache.autoload_paths_cache.has_dir?(path_suffix)
    end

    class << self
      alias_method :depend_on_without_cache, :depend_on
      def depend_on(file_name, message = "No such file to load -- %s.rb")
        depend_on_without_cache(file_name, message)
      rescue LoadError
        begin
          Thread.current[:dependencies_try_harder] = true
          depend_on_without_cache(file_name, message)
        ensure
          Thread.current[:dependencies_try_harder] = false
        end
      end
    end

    alias_method :load_missing_constant_without_cache, :load_missing_constant
    def load_missing_constant(from_mod, const_name)
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
