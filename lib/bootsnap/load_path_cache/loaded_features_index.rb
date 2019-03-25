# frozen_string_literal: true

module Bootsnap
  module LoadPathCache
    # LoadedFeaturesIndex partially mirrors an internal structure in ruby that
    # we can't easily obtain an interface to.
    #
    # This works around an issue where, without bootsnap, *ruby* knows that it
    # has already required a file by its short name (e.g. require 'bundler') if
    # a new instance of bundler is added to the $LOAD_PATH which resolves to a
    # different absolute path. This class makes bootsnap smart enough to
    # realize that it has already loaded 'bundler', and not just
    # '/path/to/bundler'.
    #
    # If you disable LoadedFeaturesIndex, you can see the problem this solves by:
    #
    # 1. `require 'a'`
    # 2. Prepend a new $LOAD_PATH element containing an `a.rb`
    # 3. `require 'a'`
    #
    # Ruby returns false from step 3.
    # With bootsnap but with no LoadedFeaturesIndex, this loads two different
    #   `a.rb`s.
    # With bootsnap and with LoadedFeaturesIndex, this skips the second load,
    #   returning false like ruby.
    class LoadedFeaturesIndex
      def initialize
        @lfi = {}
        @mutex = defined?(::Mutex) ? ::Mutex.new : ::Thread::Mutex.new # TODO: Remove once Ruby 2.2 support is dropped.

        # In theory the user could mutate $LOADED_FEATURES and invalidate our
        # cache. If this ever comes up in practice — or if you, the
        # enterprising reader, feels inclined to solve this problem — we could
        # parallel the work done with ChangeObserver on $LOAD_PATH to mirror
        # updates to our @lfi.
        $LOADED_FEATURES.each do |feat|
          hash = feat.hash
          $LOAD_PATH.each do |lpe|
            next unless feat.start_with?(lpe)
            # /a/b/lib/my/foo.rb
            #          ^^^^^^^^^
            short = feat[(lpe.length + 1)..-1]
            stripped = strip_extension(short)
            @lfi[short] = hash
            @lfi[stripped] = hash
          end
        end
      end

      # We've optimized for initialize and register to be fast, and purge to be tolerable.
      # If access patterns make this not-okay, we can lazy-invert the LFI on
      # first purge and work from there.
      def purge(feature)
        @mutex.synchronize do
          feat_hash = feature.hash
          @lfi.reject! { |_, hash| hash == feat_hash }
        end
      end

      def purge_multi(features)
        rejected_hashes = features.map(&:hash).to_set
        @mutex.synchronize do
          @lfi.reject! { |_, hash| rejected_hashes.include?(hash) }
        end
      end

      def key?(feature)
        @mutex.synchronize { @lfi.key?(feature) }
      end

      # There is a relatively uncommon case where we could miss adding an
      # entry:
      #
      # If the user asked for e.g. `require 'bundler'`, and we went through the
      # `FallbackScan` pathway in `kernel_require.rb` and therefore did not
      # pass `long` (the full expanded absolute path), then we did are not able
      # to confidently add the `bundler.rb` form to @lfi.
      #
      # We could either:
      #
      # 1. Just add `bundler.rb`, `bundler.so`, and so on, which is close but
      #    not quite right; or
      # 2. Inspect $LOADED_FEATURES upon return from yield to find the matching
      #    entry.
      def register(short, long = nil)
        if long.nil?
          pat = %r{/#{Regexp.escape(short)}(\.[^/]+)?$}
          len = $LOADED_FEATURES.size
          ret = yield
          long = $LOADED_FEATURES[len..-1].detect { |feat| feat =~ pat }
        else
          ret = yield
        end

        hash = long.hash

        # do we have 'bundler' or 'bundler.rb'?
        altname = if File.extname(short) != ''
          # strip the path from 'bundler.rb' -> 'bundler'
          strip_extension(short)
        elsif long && (ext = File.extname(long))
          # get the extension from the expanded path if given
          # 'bundler' + '.rb'
          short + ext
        end

        @mutex.synchronize do
          @lfi[short] = hash
          (@lfi[altname] = hash) if altname
        end

        ret
      end

      private

      STRIP_EXTENSION = /\.[^.]*?$/
      private_constant(:STRIP_EXTENSION)

      def strip_extension(f)
        f.sub(STRIP_EXTENSION, '')
      end
    end
  end
end
