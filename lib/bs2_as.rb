require 'msgpack'
begin
  require 'yaml'
rescue LoadError
end
require 'active_support/dependencies'

module BS2AS
  DOT_SO = '.so'.freeze
  DOT_RB = '.rb'.freeze
  LEADING_SLASH = '/'.freeze

  ReturnFalse = Class.new(StandardError)

  def self.[](feature)
    feature = feature.to_s
    if @@retfalse.include?(feature)
      raise ReturnFalse
    end
    return feature if feature.start_with?(LEADING_SLASH)
    ret = if feature =~ /\.(so|bundle|dylib)$/
      @@omg[1][feature.sub(/\..*?$/, '') + DOT_SO]
    else
      @@omg[1][feature + DOT_RB] || @@omg[1][feature] || @@omg[1][feature + DOT_SO]
    end
    if @@gfails.include?(feature)
      if ret
        raise "hey, this exists but you claimed it shouldn't"
      else
        le = LoadError.new("cannot load such file -- #{feature}")
        le.singleton_class.send(:define_method, :path) { feature }
        raise le
      end
    end
    ret
  end

  def self.setup(return_false: [], guarantee_fail: [])

    # TODO: set
    @@gfails = guarantee_fail
    @@retfalse = return_false

    if File.exist?('tmp/bs2as.msgpack')
      @@omg = MessagePack.load(File.binread('tmp/bs2as.msgpack'))
    else
      puts 'generating'
      @@omg = [
        {},
        {}
      ]
      ActiveSupport::Dependencies.autoload_paths.each do |lpe|
        req = Entry.new(lpe).requireables
        # @@omg[0][lpe] = req
        req.each do |feat, path|
          @@omg[1][feat] ||= path
        end
      end
      File.binwrite('tmp/bs2as.msgpack', MessagePack.dump(@@omg))
    end

    require_relative 'bs2/core_ext_as'
  end

  # TODO: this simulates push/<<, not unshift
  def self.load_path_added(lpe, clobber)
    p = "tmp/bs2as-#{Digest::MD5.hexdigest(lpe)}.msgpack"
    req = if File.exist?(p)
      MessagePack.load(File.binread(p))
    else
      req = Entry.new(lpe).requireables
      File.binwrite(p, MessagePack.dump(req))
      req
    end
    # @@omg[0][lpe] = req
    req.each do |feat, path|
      if clobber
        @@omg[1][feat] = path
      else
        @@omg[1][feat] ||= path
      end
    end
  end

  class Entry
    DL_EXTENSIONS = [
      RbConfig::CONFIG['DLEXT'],
      RbConfig::CONFIG['DLEXT2'],
    ].reject { |ext| !ext || ext.empty? }.map { |ext| ".#{ext}"}
    REQUIREABLE_FILES = "**/*{#{DOT_RB},.rake,#{DL_EXTENSIONS.join(',')}}"
    NORMALIZE_NATIVE_EXTENSIONS = !DL_EXTENSIONS.include?(DOT_SO)
    ALTERNATIVE_NATIVE_EXTENSIONS_PATTERN = /\.(o|bundle|dylib)\z/
    SLASH = '/'.freeze
    BUNDLE_PATH = Bundler.bundle_path.cleanpath.to_s << SLASH

    def initialize(path)
      @path = Pathname.new(path).cleanpath
      @absolute = @path.absolute?
      warn "Bootscale: Cannot speedup load for relative path #{@path}" unless @absolute
      @relative_slice = (@path.to_s.size + 1)..-1
      @contains_bundle_path = BUNDLE_PATH.start_with?(@path.to_s)
    end

    def requireables
      Dir[File.join(@path, REQUIREABLE_FILES)].each_with_object([]) do |absolute_path, all|
        next if @contains_bundle_path && absolute_path.start_with?(BUNDLE_PATH)
        relative_path = absolute_path.slice(@relative_slice)

        if NORMALIZE_NATIVE_EXTENSIONS
          relative_path.sub!(ALTERNATIVE_NATIVE_EXTENSIONS_PATTERN, DOT_SO)
        end

        all << [relative_path, @absolute && absolute_path]
      end
    end
  end

end
