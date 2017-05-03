require 'zlib'
class FetchCache
  attr_accessor :cache

  def initialize(cache)
    self.cache = cache
  end

  def self.crc(path)
    Zlib.crc32(self.file_key(path).join)
  end

  def self.file_key(path)
    [
      path,
      File.mtime(path).to_i,
      RUBY_VERSION,
      Bootsnap::VERSION
    ]
  end

  # Pack cache entry using a single uint32_t followed by an arbitrary binary string,
  # to cache raw binary strings without requiring any additional serialization.
  CACHE_PACK_FORMAT  = 'La*'

  # Fetch cached, processed contents from a file path.
  # fetch(path) {|contents, path| block } -> obj
  def fetch(path)
    file_key = self.class.crc(path)
    cache_str = cache.get(path)
    cached_file_key, data = cache_str && cache_str.unpack(CACHE_PACK_FORMAT)
    if file_key == cached_file_key
      data
    else
      yield(File.read(path), path).tap do |new_data|
        new_cache_str = [file_key, new_data].pack(CACHE_PACK_FORMAT)
        cache.set(path, new_cache_str)
      end
    end
  end
end
