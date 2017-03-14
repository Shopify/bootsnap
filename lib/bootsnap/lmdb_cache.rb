require_relative 'explicit_require'

Bootsnap::ExplicitRequire.with_gems('lmdb')    { require 'lmdb' }
Bootsnap::ExplicitRequire.with_gems('snappy')  { require 'snappy' }
Bootsnap::ExplicitRequire.with_gems('msgpack') { require 'msgpack' }

Bootsnap::ExplicitRequire.from_rubylibdir('fileutils')

module Bootsnap
  class LMDBCache
    module SnappyMessagePackMode
      def load_value(v)
        MessagePack.load(Snappy.inflate(v))
      end

      def dump_value(v)
        Snappy.deflate(MessagePack.dump(v))
      end
    end

    module SnappyMode
      def load_value(v)
        Snappy.inflate(v)
      end

      def dump_value(v)
        Snappy.deflate(v)
      end
    end

    attr_reader :env, :db

    def size
      db.size
    end

    def initialize(path, msgpack:)
      @path = path
      create_db

      mode = msgpack ? SnappyMessagePackMode : SnappyMode
      singleton_class.include(mode)

      # The LMDB Gem has a bug where the Environment garbage collection
      # handler will crash sometimes if the environment wasn't closed
      # explicitly before the reference was lost.
      ObjectSpace.define_finalizer(self, self.class.method(:finalize).to_proc)
    end

    def self.finalize(id)
      obj = ObjectSpace._id2ref(id)
      obj.close unless obj.closed?
    end

    def close
      if txn = env.active_txn
        txn.abort
      end
      env.sync
      env.close
      @closed = true
    end

    def closed?
      @closed
    end

    def inspect
      "#<#{self.class} size=#{size}>"
    end

    def fetch(key)
      value = get(key)
      return value if value
      value = yield
      set(key, value)
      value
    end

    def transaction(readonly = false)
      env.transaction(readonly) { yield }
    end

    def get(key)
      value = db.get(key)
      value && load_value(value)
    rescue Snappy::Error, LMDB::Error::CORRUPTED => error
      recover(error)
    end

    def set(key, value)
      value = dump_value(value)
      db.put(key, value)
    rescue LMDB::Error::CORRUPTED => error
      recover(error)
    end

    def delete(key)
      db.delete(key)
    rescue LMDB::Error::NOTFOUND
      nil
    end

    def clear
      reset_db
    end

    private

    def load_value(v)
      MessagePack.load(Snappy.inflate(v))
    end

    def dump_value(v)
      Snappy.deflate(MessagePack.dump(v))
    end

    def recover(error)
      puts "[Bootsnap::LMDBCache] #{error.class.name}: #{error.message}, resetting the cache"
      reset_db
      nil
    end

    def create_db
      # mapsize is the absolute maximum size of the database before it will
      # error out, it won't allocate space on disk until it's needed.
      # According to the LMDB documentation, disabling sync means we lose the D
      # in ACID (durability) We don't care about that, because a missing
      # transaction will just lead to slightly more work being done the next
      # time around.
      FileUtils.mkdir_p(@path)
      gigabyte = 1 * 1024 * 1024 * 1024
      @env = LMDB.new(@path, mapsize: 2 * gigabyte, nometasync: true, nosync: true)
      @db = env.database('cache', create: true)
    end

    def reset_db
      begin
        env.close
      rescue
        nil
      end
      FileUtils.rm_rf(@path) if File.exist?(@path)
      create_db
    end
  end
end
