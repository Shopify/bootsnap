require 'test_helper'
require 'bootsnap/load_path_cache'

module Bootsnap
  module LoadPathCache
    class PathTest < MiniTest::Test
      def setup
        @cache = Object.new
      end

      def test_stability
        bundler_file = Bundler.method(:setup).source_location[0]
        volatile     = Path.new(__FILE__)
        stable       = Path.new(bundler_file)
        unknown      = Path.new('/who/knows')
        lib          = Path.new(RbConfig::CONFIG['libdir']  + '/a')
        site         = Path.new(RbConfig::CONFIG['sitedir'] + '/b')
        bundler      = Path.new('/bp/3')

        Bundler.stubs(:bundle_path).returns('/bp')

        assert stable.stable?
        refute stable.volatile?
        assert volatile.volatile?
        refute volatile.stable?
        assert unknown.volatile?
        refute unknown.stable?

        assert lib.stable?
        refute site.stable?
        assert bundler.stable?
      end

      def test_non_directory?
        refute Path.new('/dev').non_directory?
        refute Path.new('/nope').non_directory?
        assert Path.new('/dev/null').non_directory?
        assert Path.new('/etc/hosts').non_directory?
      end

      def test_volatile_cache_valid_when_mtime_has_not_changed
        with_caching_fixtures do |dir, a, a_b, a_b_c|
          entries, dirs = PathScanner.call(dir)
          path = Path.new(dir) # volatile, since it'll be in /tmp

          @cache.expects(:get).with(dir).returns([100, entries, dirs])

          path.entries_and_dirs(@cache)
        end
      end

      def test_volatile_cache_invalid_when_mtime_changed
        with_caching_fixtures do |dir, a, a_b, a_b_c|
          entries, dirs = PathScanner.call(dir)
          path = Path.new(dir) # volatile, since it'll be in /tmp

          FileUtils.touch(a_b, mtime: Time.at(101))

          @cache.expects(:get).with(dir).returns([100, entries, dirs])
          @cache.expects(:set).with(dir, [101, entries, dirs])

          # next read doesn't regen
          @cache.expects(:get).with(dir).returns([101, entries, dirs])

          path.entries_and_dirs(@cache)
          path.entries_and_dirs(@cache)
        end
      end

      def test_volatile_cache_generated_when_missing
        with_caching_fixtures do |dir, a, a_b, a_b_c|
          entries, dirs = PathScanner.call(dir)
          path = Path.new(dir) # volatile, since it'll be in /tmp

          @cache.expects(:get).with(dir).returns(nil)
          @cache.expects(:set).with(dir, [100, entries, dirs])

          path.entries_and_dirs(@cache)
        end
      end

      def test_stable_cache_does_not_notice_when_mtime_changes
        with_caching_fixtures do |dir, a, a_b, a_b_c|
          entries, dirs = PathScanner.call(dir)
          path = Path.new(dir) # volatile, since it'll be in /tmp
          path.expects(:stable?).returns(true)

          FileUtils.touch(a_b, mtime: Time.at(101))

          # It's unfortunate that we're stubbing the impl of #fetch here.
          PathScanner.expects(:call).never
          @cache.expects(:get).with(dir).returns([100, entries, dirs])

          path.entries_and_dirs(@cache)
        end
      end

      private

      def with_caching_fixtures
        Dir.mktmpdir do |dir|
          a     = "#{dir}/a"
          a_b   = "#{dir}/a/b"
          a_b_c = "#{dir}/a/b/c.rb"
          FileUtils.mkdir_p(a_b)
          [a_b_c, a_b, a, dir].each { |f| FileUtils.touch(f, mtime: Time.at(100)) }

          yield(dir, a, a_b, a_b_c)
        end
      end
    end
  end
end
