module ActiveSupport
  module Dependencies
    class << self
      def with_bootsnap_fallback(*errors)
        yield
      rescue *errors
        bootsnap_slow_path { yield }
      end

      def bootsnap_slow_path
        prev = Thread.current[:dependencies_try_harder] || false
        Thread.current[:dependencies_try_harder] = true
        yield
      ensure
        Thread.current[:dependencies_try_harder] = prev
      end
    end

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
        Dependencies.with_bootsnap_fallback(LoadError) do
          depend_on_without_cache(file_name, message)
        end
      end
    end

    # We could do the fast lookup here too but it's not really a hot path.
    alias_method :remove_constant_without_cache, :remove_constant
    def remove_constant(const)
      Dependencies.bootsnap_slow_path do
        remove_constant_without_cache(const)
      end
    end

    alias_method :load_missing_constant_without_cache, :load_missing_constant
    def load_missing_constant(from_mod, const_name)
      Dependencies.with_bootsnap_fallback(NameError) do
        load_missing_constant_without_cache(from_mod, const_name)
      end
    end
  end
end
