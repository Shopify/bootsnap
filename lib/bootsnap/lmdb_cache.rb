require_relative 'explicit_require'

Bootsnap::ExplicitRequire.with_gems('lmdb')   { require 'lmdb' }
Bootsnap::ExplicitRequire.with_gems('snappy') { require 'snappy' }

Bootsnap::ExplicitRequire.from_rubylibdir('fileutils')

module Bootsnap
  module LMDBCache
    class Store
      attr_reader :env, :db

      def size
        db.size
      end

      # The LMDB Gem has a bug where the Environment garbage collection handler
      # will crash sometimes if the environment wasn't closed explicitly before
      # the reference was lost.  As a shitty workaround, we can make sure that we
      # never lose a reference to the Environment by putting it into a class
      # variable.
      def self.save_env(env)
        @saved_envs ||= []
        @saved_envs << env
      end

      def self.purge_env(env)
        @saved_envs.delete(env)
      end

      def initialize(path)
        @path = path
        create_db
        # Make sure we sync and close the cache on process exit.
        at_exit { close unless closed? }
      end

      def close
        env.sync
        env.close
        self.class.purge_env(env)
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

      def get(key)
        value = env.transaction do
          v = db.get(key)
          did_get(key) unless v.nil?
          v
        end
        value && load_value(value)
      rescue Snappy::Error, LMDB::Error::CORRUPTED => error
        recover(error)
      end

      def set(key, value)
        value = dump_value(value)
        env.transaction do
          db.put(key, value)
          did_set(key)
        end
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

      def did_get(key)
        # hook for LRU subclass
      end

      def did_set(key)
        # hook for LRU subclass
      end

      def load_value(v)
        Marshal.load(Snappy.inflate(v))
      end

      def dump_value(v)
        Snappy.deflate(Marshal.dump(v))
      end

      def recover(error)
        puts "[LMDBCache] #{error.class.name}: #{error.message}, resetting the cache"
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
        self.class.save_env(@env)
        @db = env.database('cache', create: true)
      end

      def reset_db
        begin
          env.close
        rescue
          nil
        end
        self.class.purge_env(env)
        FileUtils.rm_rf(@path) if File.exist?(@path)
        create_db
      end
    end

    class LRUStore < Store
      attr_reader :max_size, :lru

      def initialize(path, max_size: 20_000)
        @max_size = max_size
        super(path)
      end

      def close
        gc
        super
      end

      def inspect
        "#<#{self.class} size=#{size}/#{max_size}>"
      end

      def gc
        env.transaction do
          keys = []
          lru.each do |(hash, time)|
            keys << [time.unpack('q').first, hash]
          end
          return if keys.size <= max_size
          keys.sort!
          keys = keys.slice(0, keys.size - max_size)
          keys.each do |(_, key)|
            delete(key)
          end
        end
      end

      def delete(key)
        super
      ensure
        lru.delete(key)
      end

      private

      def did_get(key)
        update_lru(key)
      end

      def did_set(key)
        update_lru(key)
        gc if lru.size > max_size * 1.5
      end

      def create_db
        super
        @lru = env.database('lru', create: true)
      end

      def update_lru(key)
        lru.put(key, [Time.now.to_i].pack('q'))
      end
    end
  end
end
