# frozen_string_literal: true

require_relative('../explicit_require')
require 'bootsnap/dirscanner'

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

      def self.call(path, excluded_paths: Bootsnap::LoadPathCache.exclude_paths)
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

        process_path = ->(absolute_path) do
          next if contains_bundle_path && absolute_path.start_with?(BUNDLE_PATH)
          relative_path = absolute_path.slice(relative_slice)

          if File.directory?(absolute_path)
            dirs << relative_path
          elsif REQUIRABLE_EXTENSIONS.include?(File.extname(relative_path))
            requirables << relative_path
          end
        end

        excluded = excluded_paths || []

        if ENV['BOOTSNAP_EXPERIMENTAL']
          DirScanner.scan(path, excluded: excluded) do |path|
            process_path.(path)
          end
        else
          Dir.glob(path + ALL_FILES).each do |path|
            next if excluded.any?{ |excl| path.start_with?(excl) }
            process_path.(path)
          end
        end

        [requirables, dirs]
      end
    end
  end
end
