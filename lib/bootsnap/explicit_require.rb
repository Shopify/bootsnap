module Bootsnap
  module ExplicitRequire
    ARCHDIR    = RbConfig::CONFIG['archdir']
    RUBYLIBDIR = RbConfig::CONFIG['rubylibdir']
    DLEXT      = RbConfig::CONFIG['DLEXT']

    def self.from_archdir(feature)
      require(File.join(ARCHDIR, "#{feature}.#{DLEXT}"))
    end

    def self.with_gems(*gems)
      orig = $LOAD_PATH.dup
      $LOAD_PATH.clear
      gems.each do |gem|
        pat = %r{
          /
          (gems|extensions/[^/]+/[^/]+)          # "gems" or "extensions/x64_64-darwin16/2.3.0"
          /
          #{Regexp.escape(gem)}-(\h{12}|(\d+\.)) # msgpack-1.2.3 or msgpack-1234567890ab
        }x
        $LOAD_PATH.concat(orig.grep(pat))
      end
      $LOAD_PATH << ARCHDIR
      $LOAD_PATH << RUBYLIBDIR
      yield
    ensure
      $LOAD_PATH.replace(orig)
    end
  end
end
