require 'fileutils'
require 'lmdb'

module Bootsnap
  module CompileCache
    module LMDB
      MAX_SIZE = 2 ** 30 # 1GiB

      class << self
        def fetch(cache_dir, path, handler)
          ensure_database_exists!(cache_dir)

          # TODO: check wether it's inside GEM_PATH
          # We could consider gems as immutable and save this `mtime`.
          source_mtime = File.mtime(path).to_i
          cache_mtime = @database.get("mtime:#{path}").to_i

          if cache_mtime >= source_mtime
            handler.storage_to_output(@database.get(path))
          else
            content = handler.input_to_storage(nil, path)
            @database.put(path, content)
            @database.put("mtime:#{path}", source_mtime.to_s)
            handler.storage_to_output(content)
          end
        end

        def ensure_database_exists!(cache_dir)
          return if defined? @database

          FileUtils.mkdir_p(cache_dir)
          @env = ::LMDB.new(File.join(cache_dir), mapsize: MAX_SIZE, nometasync: true, nosync: true)
          @database = @env.database('bootsnap', create: true)
        end
      end
    end
  end
end
