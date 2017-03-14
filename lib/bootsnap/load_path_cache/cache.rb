require_relative '../load_path_cache'
require_relative '../explicit_require'
Bootsnap::ExplicitRequire.from_archdir('thread')

module Bootsnap
  module LoadPathCache
    class Cache
      AGE_THRESHOLD = 30

      def initialize(store, path_obj, development_mode: false)
        @development_mode = development_mode
        @cache = store
        @mutex = ::Thread::Mutex.new
        @path_obj = path_obj
        reinitialize
      end

      # Does this directory exist as a child of one of the path items?
      # e.g. given "/a/b/c/d" exists, and the path is ["/a/b"], has_dir?("c/d")
      # is true.
      def has_dir?(dir)
        reinitialize if stale?
        @mutex.synchronize { @dirs[dir] }
      end

      # Try to resolve this feature to an absolute path without traversing the
      # loadpath
      def find(feature)
        reinitialize if stale?
        @mutex.synchronize do
          feature = feature.to_s
          return feature if feature.start_with?(SLASH)
          search_index(feature)
        end
      end

      def unshift_paths(*paths)
        @mutex.synchronize { unshift_paths_locked(*paths) }
      end

      def push_paths(*paths)
        @mutex.synchronize { push_paths_locked(*paths) }
      end

      private

      def reinitialize
        @mutex.synchronize do
          @index = {}
          @dirs = Hash.new(false)
          @generated_at = now
          push_paths_locked(*@path_obj)
        end
      end

      def push_paths_locked(*paths)
        paths.each do |path|
          p = Path.new(path)
          entries, dirs = p.entries_and_dirs(@cache)
          # push -> low precedence -> set only if unset
          dirs.each    { |dir| @dirs[dir]  ||= true }
          entries.each { |rel| @index[rel] ||= path }
        end
      end

      def unshift_paths_locked(*paths)
        paths.reverse.each do |path|
          p = Path.new(path)
          entries, dirs = p.entries_and_dirs(@cache)
          # unshift -> high precedence -> unconditional set
          dirs.each    { |dir| @dirs[dir]  = true }
          entries.each { |rel| @index[rel] = path }
        end
      end

      def stale?
        @development_mode && @generated_at + AGE_THRESHOLD < now
      end

      def now
        Process.clock_gettime(Process::CLOCK_MONOTONIC).to_i
      end

      if DLEXT2
        def search_index(f)
          try_index(f + DOT_RB) || try_index(f + DLEXT) || try_index(f + DLEXT2) || try_index(f)
        end
      else
        def search_index(f)
          try_index(f + DOT_RB) || try_index(f + DLEXT) || try_index(f)
        end
      end

      def try_index(f)
        if p = @index[f]
          return p + '/' + f
        end
      end
    end
  end
end

