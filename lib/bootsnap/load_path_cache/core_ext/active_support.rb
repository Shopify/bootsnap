module Bootsnap
  module LoadPathCache
    module CoreExt
      module ActiveSupport
        def self.with_bootsnap_fallback(error)
          yield
        rescue error
          bootsnap_slow_path { yield }
        end

        def self.bootsnap_slow_path
          prev = Thread.current[:dependencies_try_harder] || false
          Thread.current[:dependencies_try_harder] = true
          yield
        ensure
          Thread.current[:dependencies_try_harder] = prev
        end

        module ClassMethods
          def autoload_paths=(o)
            r = super
            Bootsnap::LoadPathCache.autoload_paths_cache.reinitialize(o)
            r
          end

          def search_for_file(path)
            return super if Thread.current[:dependencies_try_harder]
            begin
              Bootsnap::LoadPathCache.autoload_paths_cache.find(path)
            rescue Bootsnap::LoadPathCache::ReturnFalse
              nil # doesn't really apply here
            end
          end

          def autoloadable_module?(path_suffix)
            Bootsnap::LoadPathCache.autoload_paths_cache.has_dir?(path_suffix)
          end

          def remove_constant(const)
            CoreExt::ActiveSupport.bootsnap_slow_path { super }
          end

          def load_missing_constant(from_mod, const_name)
            CoreExt::ActiveSupport.with_bootsnap_fallback(NameError) { super }
          end

          def depend_on(file_name, message = "No such file to load -- %s.rb")
            CoreExt::ActiveSupport.with_bootsnap_fallback(LoadError) { super }
          end
        end
      end
    end
  end
end

module ActiveSupport
  module Dependencies
    class << self
      prepend Bootsnap::LoadPathCache::CoreExt::ActiveSupport::ClassMethods
    end
  end
end
