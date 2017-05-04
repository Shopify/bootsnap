# Wrapper to accept a number of common cache implementations.
module Bootsnap
  class CacheWrapper
    def self.get(cache)
      # `Cache#get(key)` for Memcache
      if cache.respond_to?(:get)
        GetWrapper.new(cache)

      # `Cache#[key]` so `Hash` can be used
      elsif cache.respond_to?(:[])
        HashWrapper.new(cache)

      # `Cache#read(key)` for `ActiveSupport::Cache` support
      elsif cache.respond_to?(:read)
        ReadWriteWrapper.new(cache)

      else
        nil
      end
    end

    class Wrapper < Struct.new(:cache)
    end

    class GetWrapper < Wrapper
      def get(key)
        cache.get(key)
      end

      def set(key, value)
        cache.set(key, value)
      end
    end

    class HashWrapper < Wrapper
      def get(key)
        cache[key]
      end

      def set(key, value)
        cache[key] = value
      end
    end

    class ReadWriteWrapper < Wrapper
      def get(key)
        cache.read(key)
      end

      def set(key, value)
        cache.write(key, value)
      end
    end
  end
end
