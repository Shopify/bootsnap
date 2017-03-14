require_relative 'lmdb_cache'

module Bootsnap
  module LoadPathCache
    ReturnFalse = Class.new(StandardError)

    DOT_RB = '.rb'
    DOT_SO = '.so'
    SLASH  = '/'

    DL_EXTENSIONS = ::RbConfig::CONFIG
      .values_at('DLEXT', 'DLEXT2')
      .reject { |ext| !ext || ext.empty? }
      .map    { |ext| ".#{ext}" }
      .freeze
    DLEXT = DL_EXTENSIONS[0]
    DLEXT2 = DL_EXTENSIONS[1]

    class << self
      attr_reader :load_path_cache, :autoload_paths_cache

      def setup(cache_path:, development_mode:, active_support: true)
        store = Bootsnap::LMDBCache.new(cache_path)
        at_exit { store.close }

        @load_path_cache = start_cache(store, $LOAD_PATH, development_mode: development_mode)
        require_relative 'load_path_cache/core_ext/kernel_require'

        if active_support
          # this should happen after setting up the initial cache because it
          # loads a lot of code. It's better to do after +require+ is optimized.
          require 'active_support/dependencies'
          @autoload_paths_cache = start_cache(
            store,
            ::ActiveSupport::Dependencies.autoload_paths,
            development_mode: development_mode
          )
          require_relative 'load_path_cache/core_ext/active_support'
        end
      end

      private

      def start_cache(store, obj, development_mode:)
        c = Cache.new(store, obj, development_mode: development_mode)
        ChangeObserver.register(c, obj)
        c
      end
    end
  end
end

require_relative 'load_path_cache/path_scanner'
require_relative 'load_path_cache/path'
require_relative 'load_path_cache/cache'
require_relative 'load_path_cache/change_observer'
