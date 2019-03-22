# frozen_string_literal: true

require_relative('../explicit_require')

module Bootsnap
  module LoadPathCache
    module PathScanner
      ALL_FILES = "/{,**/*/**/}*"
      REQUIRABLE_EXTENSIONS = [DOT_RB] + DL_EXTENSIONS
      NORMALIZE_NATIVE_EXTENSIONS = !DL_EXTENSIONS.include?(LoadPathCache::DOT_SO)
      ALTERNATIVE_NATIVE_EXTENSIONS_PATTERN = /\.(o|bundle|dylib)\z/

      BUNDLE_PATH = if Bootsnap.bundler?
        (Bundler.bundle_path.cleanpath.to_s << LoadPathCache::SLASH).freeze
      else
        ''
      end

      def self.call(path)
        path = path.to_s

        relative_slice = (path.size + 1)..-1
        # If the bundle path is a descendent of this path, we do additional
        # checks to prevent recursing into the bundle path as we recurse
        # through this path. We don't want to scan the bundle path because
        # anything useful in it will be present on other load path items.
        #
        # This can happen if, for example, the user adds '.' to the load path,
        # and the bundle path is '.bundle'.
        contains_bundle_path = BUNDLE_PATH.start_with?(path)

        dirs = []
        requirables = []

        Dir.glob(path + ALL_FILES).each do |absolute_path|
          next if contains_bundle_path && absolute_path.start_with?(BUNDLE_PATH)
          relative_path = absolute_path.slice(relative_slice)

          if File.directory?(absolute_path)
            dirs << relative_path
          elsif REQUIRABLE_EXTENSIONS.include?(File.extname(relative_path))
            requirables << relative_path
          end
        end

        [requirables, dirs]
      end
    end
  end
end
