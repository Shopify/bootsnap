module Bootsnap
  module LoadPathCache
    class Entry
      DL_EXTENSIONS = [
        RbConfig::CONFIG['DLEXT'],
        RbConfig::CONFIG['DLEXT2'],
      ].compact.reject(&:empty?).map { |ext| ".#{ext}" }
      REQUIREABLE_FILES = "**/*{#{DOT_RB},#{DOT_RAKE},#{DL_EXTENSIONS.join(',')}}"

      NORMALIZE_NATIVE_EXTENSIONS = !DL_EXTENSIONS.include?(DOT_SO)
      BUNDLE_PATH = Bundler.bundle_path.cleanpath.to_s << SLASH
      RUBY_PREFIX = RbConfig::CONFIG['prefix'] << SLASH

      def to_s
        @path
      end

      def path
        @path
      end

      attr_reader :index

      def initialize(path, index)
        unless path.start_with?('/')
          raise "relative paths not supported by bootsnap load path caching"
        end

        # Bootscale uses a Pathname here, but it's such a slow library :(
        @path = File.absolute_path(path).freeze
        @index = index
      end

      # If the path is part of the ruby distribution or the bundle, its
      # contents are exceedingly unlikely to change over time.
      def static?
        @path.start_with?(BUNDLE_PATH, RUBY_PREFIX)
      end

      def features
        relative_slice = (@path.size + 1)..-1
        pattern = File.join(@path, REQUIREABLE_FILES)
        contains_bundle_path = BUNDLE_PATH.start_with?(@path)

        Dir.glob(pattern).each_with_object([]) do |absolute_path, acc|
          next if contains_bundle_path && absolute_path.start_with?(BUNDLE_PATH)
          relative_path = absolute_path.slice(relative_slice)

          if NORMALIZE_NATIVE_EXTENSIONS
            relative_path.sub!(ALTERNATIVE_NATIVE_EXTENSIONS_PATTERN, DOT_SO)
          end

          acc << relative_path
        end
      end
    end
  end
end
