require_relative '../load_path_cache'
require_relative '../explicit_require'

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

      # { 'enumerator' => nil, 'enumerator.so' => nil, ... }
      BUILTIN_FEATURES = $LOADED_FEATURES.reduce({}) do |acc, feat|
        # Builtin features are of the form 'enumerator.so'.
        # All others include paths.
        next acc unless feat.size < 20 && !feat.include?('/')

        base = File.basename(feat, '.*') # enumerator.so -> enumerator
        ext  = File.extname(feat) # .so

        acc[feat] = nil # enumerator.so
        acc[base] = nil # enumerator

        if [DOT_SO, *DL_EXTENSIONS].include?(ext)
          DL_EXTENSIONS.each do |ext|
            acc["#{base}#{ext}"] = nil # enumerator.bundle
          end
        end

        acc
      end.freeze

      # Try to resolve this feature to an absolute path without traversing the
      # loadpath.
      def find(feature)
        reinitialize if stale?
        feature = feature.to_s
        return feature if feature.start_with?(SLASH)
        return File.expand_path(feature) if feature.start_with?('./')
        @mutex.synchronize do
          x = search_index(feature)
          return x if x

          # Ruby has some built-in features that require lies about.
          # For example, 'enumerator' is built in. If you require it, ruby
          # returns false as if it were already loaded; however, there is no
          # file to find on disk. We've pre-built a list of these, and we
          # return false if any of them is loaded.
          raise LoadPathCache::ReturnFalse if BUILTIN_FEATURES.key?(feature)

          # The feature wasn't found on our preliminary search through the index.
          # We resolve this differently depending on what the extension was.
          case File.extname(feature)
          # If the extension was one of the ones we explicitly cache (.rb and the
          # native dynamic extension, e.g. .bundle or .so), we know it was a
          # failure and there's nothing more we can do to find the file.
          when '', *CACHED_EXTENSIONS # no extension, .rb, (.bundle or .so)
            nil
          # Ruby allows specifying native extensions as '.so' even when DLEXT
          # is '.bundle'. This is where we handle that case.
          when DOT_SO
            x = search_index(feature[0..-4] + DLEXT)
            return x if x
            if DLEXT2
              search_index(feature[0..-4] + DLEXT2)
            end
          else
            # other, unknown extension. For example, `.rake`. Since we haven't
            # cached these, we legitimately need to run the load path search.
            raise LoadPathCache::FallbackScan
          end
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
        paths.map(&:to_s).each do |path|
          p = Path.new(path)
          next if p.non_directory?
          entries, dirs = p.entries_and_dirs(@store)
          # push -> low precedence -> set only if unset
          dirs.each    { |dir| @dirs[dir]  ||= true }
          entries.each { |rel| @index[rel] ||= path }
        end
      end

      def unshift_paths_locked(*paths)
        paths.map(&:to_s).reverse.each do |path|
          p = Path.new(path)
          next if p.non_directory?
          entries, dirs = p.entries_and_dirs(@store)
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
          p + '/' + f
        end
      end
    end
  end
end
