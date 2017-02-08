module Bootsnap
  module LoadPathCache
    class Cache
      def initialize(dbfile, guarantee_fail = [], return_false = [])
        @dbfile = dbfile
        @guarantee_fail = Hash[guarantee_fail.map { |x| [x, true] }]
        @return_false   = Hash[return_false.map { |x| [x, true] }]

        @cache = {}
        @cache_indices = {}
        @lbound = 0
        @rbound = 0
        @queue = Queue.new

        # Thread.new do
        #   loop do
        #     entries = Array(@queue.pop)
        #     features_by_entry = {}
        #     populate_entries(entries, features_by_entry)
        #     merge_cache(features_by_entry)
        #   end
        # end

        require_relative 'core_ext'
        add_paths(*$LOAD_PATH, front: false)
      end

      def [](feature)
        feature = feature.to_s
        return feature if feature.start_with?(SLASH)
        raise ReturnFalse if @return_false[feature]

        ret = lookup(feature)
        if @guarantee_fail[feature]
          if ret
            raise "Bootsnap.setup specified guarantee_fail for feature but feature was found in LOAD_PATH: #{feature}"
          else
            le = LoadError.new("cannot load such file -- #{feature}")
            le.singleton_class.send(:define_method, :path) { feature }
            raise le
          end
        end

        # puts "[bootsnap] failed lookup for feature: #{feature}" if ret.nil?
        ret
      end

      def add_paths(*paths, front:)
        return if paths.empty?

        entries = []

        if front
          start = @lbound
          entries = paths.each_with_index.map do |path, index|
            Entry.new(path, start - (index + 1))
          end
          @lbound -= paths.size
        else
          start = @rbound
          entries = paths.each_with_index.map do |path, index|
            Entry.new(path, index + start)
          end
          @rbound += paths.size
        end

        features_by_entry = {}
        scan_fg = []
        scan_bg = []

        with_db(write: false) do |db|
          entries.each do |entry|
            value = db[entry.path]
            if value.nil?
              scan_fg << entry
            else
              features_by_entry[entry] = MessagePack.load(value)
              scan_bg << entry unless entry.static?
            end
          end
        end

        # Before returning, populate the cache for any missing entries
        populate_entries(scan_fg, features_by_entry) unless scan_fg.empty?

        # After returning, repopulate the cache with any non-static paths.
        # (i.e. anything not part of the bundle or ruby distribution)
        @queue << scan_bg

        merge_cache(features_by_entry)
      end

      private

      def lookup(feature)
        SEMAPHORE.synchronize do
          entry = @cache[feature] || \
          @cache[feature + DOT_RB] || \
          @cache[feature + DOT_SO] || \
          @cache[feature.sub(ALTERNATIVE_NATIVE_EXTENSIONS_PATTERN, DOT_SO)]
          entry ? "#{entry.path}/#{feature}" : nil
        end
      end

      def merge_cache(features_by_entry)
        SEMAPHORE.synchronize do
          features_by_entry.each do |entry, features|
            features.each do |feature|
              existing = @cache[feature]
              next if existing && existing.index < entry.index
              @cache[feature] = entry
            end
          end
        end
      end

      def populate_entries(entries, features_by_entry)
        kv_pairs = entries.map do |entry|
          features = entry.features
          features_by_entry[entry] = features # side effect!
          [entry.to_s, MessagePack.dump(features)]
        end

        with_db(write: true) do |db|
          kv_pairs.each { |k, v| db[k] = v }
        end

        features_by_entry
      end

      def with_db(write: false, &block)
        File.open("#{@dbfile}.db", File::RDWR | File::CREAT, 0644) do |f|
          f.flock(write ? File::LOCK_EX : File::LOCK_SH)
          DBM.open(@dbfile, 0644, DBM::WRCREAT, &block)
        end
      end
    end
  end
end

