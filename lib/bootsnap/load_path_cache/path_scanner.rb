require_relative '../load_path_cache'

module BootLib
  module LoadPathCache
    module PathScanner
      RelativePathNotSupported = Class.new(StandardError)

      def self.call(path)
        raise RelativePathNotSupported unless path.start_with?(SLASH)

        relative_slice = (path.size + 1)..-1
        contains_bundle_path = BUNDLE_PATH.start_with?(path)

        dirs = []
        requirables = []

        Dir.glob(path + REQUIRABLES_AND_DIRS).each do |absolute_path|
          next if contains_bundle_path && absolute_path.start_with?(BUNDLE_PATH)
          relative_path = absolute_path.slice!(relative_slice)

          if md = relative_path.match(IS_DIR)
            dirs << md[1]
          else
            requirables << relative_path
          end
        end
        [requirables, dirs]
      end

      private

      REQUIRABLES_AND_DIRS = "/**/*{#{DOT_RB},#{DL_EXTENSIONS.join(',')},/}"
      IS_DIR = %r{(.*)/\z}
      NORMALIZE_NATIVE_EXTENSIONS = !DL_EXTENSIONS.include?(LoadPathCache::DOT_SO)
      ALTERNATIVE_NATIVE_EXTENSIONS_PATTERN = /\.(o|bundle|dylib)\z/
      BUNDLE_PATH = (Bundler.bundle_path.cleanpath.to_s << LoadPathCache::SLASH).freeze
    end
  end
end
