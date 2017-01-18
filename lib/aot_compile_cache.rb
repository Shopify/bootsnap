require 'aot_compile_cache/version'
require 'aot_compile_cache/aot_compile_cache'

# These don't benefit from the ISeq patch, so keep the list short.
require 'cityhash'
require 'fiddle'
require 'fileutils'

# These are loaded in config/boot.rb after applying the ISeq patch.
#   require 'yaml'

class AOTCompileCache
  class ISeq < AOTCompileCache
    def self.input_to_storage(_, path)
      RubyVM::InstructionSequence.compile_file(path).to_binary
    rescue SyntaxError
      raise Uncompileable, 'syntax error'
    end

    def self.storage_to_output(binary)
      RubyVM::InstructionSequence.load_from_binary(binary)
    end

    def self.input_to_output
      nil # ruby handles this
    end
  end

  # KEY_VERSION can be changed to invalidate cached data.
  KEY_VERSION       = 0x05 # one byte
  XATTR_KEY_NAME    = 'com.shopify.AOTCacheKey'
  # version(uint8) + size(uint32) + revision(uint32) + mtime(uint64) + hash(uint64)
  XATTR_KEY_SIZE    = 1 + 4 + 4 + 8 + 8
  XATTR_KEY_FORMAT  = 'CLLQQ'
  XATTR_DATA_NAME   = 'com.apple.ResourceFork'

  Uncacheable   = Class.new(StandardError)
  Uncompileable = Class.new(StandardError)

  # This is written kind of weirdly.
  # The idea is to generate:
  #
  #   open("/path/to/file.rb", ...) = 7 0 # open file (once!)
  #   fstat64(0x7, ...)                   # fetch mtime
  #   fgetxattr(0x7, ...)                 # fetch cache key
  #   fgetxattr(0x7, ...)                 # fetch cache data
  #   close(0x7)                          # close file
  #
  # More naive implementations generate a bunch more syscalls,
  # or open the file multiple times.
  #
  # To trace on macOS, you have to reboot into recovery mode and run:
  #   csrutil disable
  # Then:
  #   sudo -E dtruss -f bundle exec rake environment 2> out.dtruss
  def self.fetch(srcpath)
    srcpath = srcpath.to_s
    src_fd = File.sysopen(srcpath)

    actual_mtime = Native.fmtime(src_fd)
    xattr_key = begin
      Native.fgetxattr(src_fd, XATTR_KEY_NAME, XATTR_KEY_SIZE)
    rescue Errno::ENOATTR, Errno::ERANGE
      nil
    end

    if xattr_key
      version, data_size, ruby_revision, cached_mtime, cached_checksum = xattr_key.unpack(XATTR_KEY_FORMAT)
      if version != KEY_VERSION || ruby_revision != RUBY_REVISION
        data_size = nil
        cached_mtime = nil
        cached_checksum = nil
      end
    end

    if cached_mtime && cached_mtime == actual_mtime
      buf = Native.fgetxattr(src_fd, XATTR_DATA_NAME, data_size)
      Native.close(src_fd)
      return storage_to_output(buf)
    end

    srcfile = IO.new(src_fd, 'r')
    source_contents = srcfile.read
    actual_checksum = CityHash.hash64(source_contents)

    if cached_checksum && cached_checksum == actual_checksum
      buf = Native.fgetxattr(src_fd, XATTR_DATA_NAME, data_size)

      # reset the key with the new mtime
      key_data = [KEY_VERSION, data_size, RUBY_REVISION, actual_mtime, actual_checksum].pack(XATTR_KEY_FORMAT)
      Native.fsetxattr(src_fd, XATTR_KEY_NAME, key_data)

      # setxattr bumps mtime, and we want it to be stable
      srcfile.close
      FileUtils.touch(srcpath, mtime: actual_mtime)
      return storage_to_output(buf)
    end

    begin
      storage = input_to_storage(source_contents, srcpath)
      # xattrs can only be 64MB. fail more gracefully maybe?
      if storage.size > 64 * 1024 * 1024
        # TODO: we could split this into multiple xattrs or use a file
        # or at least a real error class
        srcfile.close
        raise 'too much data'
      end

      key_data = [KEY_VERSION, storage.size, RUBY_REVISION, actual_mtime, actual_checksum].pack(XATTR_KEY_FORMAT)

      # maybe faster on darwin?
      # File.binwrite(resource_fork, storage)
      Native.fsetxattr(src_fd, XATTR_DATA_NAME, storage)
      Native.fsetxattr(src_fd, XATTR_KEY_NAME, key_data)
      # setxattr bumps mtime, and we want it to be stable
      srcfile.close
      FileUtils.touch(srcpath, mtime: actual_mtime)
    rescue Uncacheable => e
      srcfile.close
      log "caching failed for #{srcpath}: #{e.message}"
    rescue Uncompileable => e
      srcfile.close
      log "compilation failed for #{srcpath}: #{e.message}"
      storage = nil
    rescue Errno::EACCES
      srcfile.close
      log "no permissions to write cache for #{srcpath}"
    end

    if storage.nil?
      return input_to_output(source_contents)
    end
    storage_to_output(storage)
  end

  def self.log(msg)
    return unless ENV['DEBUG_AOT']
    STDERR.puts "[aot-compile-cache] #{msg}"
  end

  class YAML < AOTCompileCache
    def self.input_to_storage(contents, _)
      obj = ::YAML.load(contents)
      Marshal.dump(obj)
    end

    def self.storage_to_output(data)
      Marshal.load(data)
    end

    def self.input_to_output(data)
      ::YAML.load(data)
    end
  end
end
