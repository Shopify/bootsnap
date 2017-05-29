require 'test_helper'

module Bootsnap
  module LoadPathCache
    class CacheTest < MiniTest::Test
      def setup
        @dir1 = Dir.mktmpdir
        @dir2 = Dir.mktmpdir
        FileUtils.touch("#{@dir1}/a.rb")
        FileUtils.mkdir_p("#{@dir1}/foo/bar")
        FileUtils.touch("#{@dir1}/foo/bar/baz.rb")
        FileUtils.touch("#{@dir2}/b.rb")
        FileUtils.touch("#{@dir1}/conflict.rb")
        FileUtils.touch("#{@dir2}/conflict.rb")
        FileUtils.touch("#{@dir1}/dl#{DLEXT}")
        FileUtils.touch("#{@dir1}/both.rb")
        FileUtils.touch("#{@dir1}/both#{DLEXT}")
      end

      def teardown
        FileUtils.rm_rf(@dir1)
        FileUtils.rm_rf(@dir2)
      end

      # dev.yml specifies 2.3.3 and this test assumes it. Failures on other
      # versions aren't a big deal, but feel free to fix the test.
      def test_builtin_features
        cache = Cache.new(NullCache, [])
        assert_raises(ReturnFalse) { cache.find('thread') }
        assert_raises(ReturnFalse) { cache.find('thread.rb') }
        assert_raises(ReturnFalse) { cache.find('enumerator') }
        assert_raises(ReturnFalse) { cache.find('enumerator.so') }
        assert_raises(ReturnFalse) { cache.find('enumerator.bundle') }

        refute(cache.find('thread.bundle'))
        refute(cache.find('enumerator.rb'))
        refute(cache.find('encdb.bundle'))
      end

      def test_simple
        po = [@dir1]
        cache = Cache.new(NullCache, po)
        assert_equal("#{@dir1}/a.rb", cache.find('a'))
        cache.push_paths(po, @dir2)
        assert_equal("#{@dir2}/b.rb", cache.find('b'))
      end

      def test_unshifted_paths_have_higher_precedence
        po = [@dir1]
        cache = Cache.new(NullCache, po)
        assert_equal("#{@dir1}/conflict.rb", cache.find('conflict'))
        cache.unshift_paths(po, @dir2)
        assert_equal("#{@dir2}/conflict.rb", cache.find('conflict'))
      end

      def test_pushed_paths_have_lower_precedence
        po = [@dir1]
        cache = Cache.new(NullCache, po)
        assert_equal("#{@dir1}/conflict.rb", cache.find('conflict'))
        cache.push_paths(po, @dir2)
        assert_equal("#{@dir1}/conflict.rb", cache.find('conflict'))
      end

      def test_directory_caching
        cache = Cache.new(NullCache, [@dir1])
        assert cache.has_dir?("foo")
        assert cache.has_dir?("foo/bar")
        refute cache.has_dir?("bar")
      end

      def test_extension_permutations
        cache = Cache.new(NullCache, [@dir1])
        assert_equal("#{@dir1}/dl#{DLEXT}", cache.find('dl'))
        assert_equal("#{@dir1}/dl#{DLEXT}", cache.find("dl#{DLEXT}"))
        assert_equal("#{@dir1}/both.rb", cache.find("both"))
        assert_equal("#{@dir1}/both.rb", cache.find("both.rb"))
        assert_equal("#{@dir1}/both#{DLEXT}", cache.find("both#{DLEXT}"))
      end

      def test_relative_paths_rescanned
        Dir.chdir(@dir2) do
          cache = Cache.new(NullCache, ['foo'])
          refute(cache.find('bar/baz'))
          Dir.chdir(@dir1) do
            # one caveat here is that you get the actual path back when
            # resolving relative paths. On darwin, this means that
            # /var/folders/... comes back as /private/var/folders/... -- In
            # production, this should be fine, but for this test to pass, we
            # have to resolve it.
            assert_equal(File.realpath("#{@dir1}/foo/bar/baz.rb"), cache.find('bar/baz'))
          end
        end
      end

      def test_development_mode
        time = Process.clock_gettime(Process::CLOCK_MONOTONIC).to_i

        # without development_mode, no refresh
        dev_no_cache = Cache.new(NullCache, [@dir1], development_mode: false)
        dev_yes_cache = Cache.new(NullCache, [@dir1], development_mode: true)

        FileUtils.touch("#{@dir1}/new.rb")

        dev_no_cache.stubs(:now).returns(time + 31)
        refute dev_no_cache.find('new')

        dev_yes_cache.stubs(:now).returns(time + 28)
        refute dev_yes_cache.find('new')
        dev_yes_cache.stubs(:now).returns(time + 31)
        assert dev_yes_cache.find('new')
      end
    end
  end
end
