require_relative '../explicit_require'

Bootsnap::ExplicitRequire.with_gems('msgpack') { require 'msgpack' }
Bootsnap::ExplicitRequire.with_gems('snappy') { require 'snappy' }
Bootsnap::ExplicitRequire.from_rubylibdir('fileutils')

# Fix method signature in Snappy::Reader to ignore arguments passed to #read.
module SnappyReaderPatch
  def read(*_)
    super()
  end
end
Snappy::Reader.prepend SnappyReaderPatch

module Bootsnap
  module LoadPathCache
    class Store
      def initialize(store_path)
        @store_path = store_path
        load_data
        at_exit {dump_data if @dirty}
      end

      def get(key)
        @data[key]
      end

      def fetch(key)
        v = get(key)
        unless v
          @dirty = true
          v = yield
          @data[key] = v
        end
        v
      end

      def set(key, value)
        if value != @data[key]
          @dirty = true
          @data[key] = value
        end
      end

      def transaction
        yield
      end

      private

      def load_data
        @data = begin
          store_file = File.new(@store_path, 'r')
          MessagePack.load(Snappy::Reader.new(store_file))
        # handle malformed data due to upgrade incompatability
        rescue Errno::ENOENT, MessagePack::MalformedFormatError, MessagePack::UnknownExtTypeError, EOFError
          {}
        end
      end

      def dump_data
        # Change contents atomically so other processes can't get invalid
        # caches if they read at an inopportune time.
        tmp = "#{@store_path}.#{(rand * 100000).to_i}.tmp"
        FileUtils.mkpath(File.dirname(tmp))
        Snappy::Writer.new(File.new(tmp, 'w')) do |w|
          MessagePack.dump(@data, w)
        end
        FileUtils.mv(tmp, @store_path)
      end
    end
  end
end
