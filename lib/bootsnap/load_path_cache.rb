require_relative 'explicit_require'
Bootsnap::ExplicitRequire.from_archdir('dbm')
Bootsnap::ExplicitRequire.from_archdir('thread')
Bootsnap::ExplicitRequire.with_gems('msgpack') { require 'msgpack' }

module Bootsnap
  module LoadPathCache
    DOT_RB   = '.rb'
    DOT_SO   = '.so'
    DOT_RAKE = '.rake'
    SLASH    = '/'.freeze
    ALTERNATIVE_NATIVE_EXTENSIONS_PATTERN = /\.(o|bundle|dylib)\z/
    SEMAPHORE = Mutex.new

    ReturnFalse = Class.new(StandardError)

    class << self
      attr_accessor :load_path_cache
      attr_accessor :autoload_path_cache
    end
  end
end

require_relative 'load_path_cache/entry'
require_relative 'load_path_cache/cache'
