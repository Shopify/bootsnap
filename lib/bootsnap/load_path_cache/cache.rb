require_relative '../load_path_cache'
require_relative '../explicit_require'
Bootsnap::ExplicitRequire.from_archdir('thread')

module Bootsnap
  module LoadPathCache
    class Cache
      AGE_THRESHOLD = 30 # seconds

      def initialize(store, path_obj, development_mode: false)
        @development_mode = development_mode
        @store = store
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
        feature = feature.to_s
        return feature if feature.start_with?(SLASH)
        @mutex.synchronize do
          search_index(feature)
        end
      end

      def unshift_paths(sender, *paths)
        return unless sender == @path_obj
        @mutex.synchronize { unshift_paths_locked(*paths) }
      end

      def push_paths(sender, *paths)
        return unless sender == @path_obj
        @mutex.synchronize { push_paths_locked(*paths) }
      end

      def each_requirable
        @mutex.synchronize do
          @index.each do |rel, entry|
            yield "#{entry}/#{rel}"
          end
        end
      end

      def reinitialize(path_obj = @path_obj)
        @mutex.synchronize do
          @path_obj = path_obj
          ChangeObserver.register(self, @path_obj)
          @index = {}
          @dirs = Hash.new(false)
          @generated_at = now
          push_paths_locked(*@path_obj)
        end
      end

      private

      def push_paths_locked(*paths)
        @store.transaction do
          paths.each do |path|
            p = Path.new(path)
            entries, dirs = p.entries_and_dirs(@store)
            # push -> low precedence -> set only if unset
            dirs.each    { |dir| @dirs[dir]  ||= true }
            entries.each { |rel| @index[rel] ||= path }
          end
        end
      end

      def unshift_paths_locked(*paths)
        @store.transaction do
          paths.reverse.each do |path|
            p = Path.new(path)
            entries, dirs = p.entries_and_dirs(@store)
            # unshift -> high precedence -> unconditional set
            dirs.each    { |dir| @dirs[dir]  = true }
            entries.each { |rel| @index[rel] = path }
          end
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
          p + '/' + f
        end
      end
    end
  end
end
