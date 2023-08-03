# frozen_string_literal: true

require("test_helper")

module Bootsnap
  class KernelRequireTest < Minitest::Test
    include LoadPathCacheHelper

    def test_uses_the_same_duck_type_as_require
      skip("Need a working Process.fork to test in isolation") unless Process.respond_to?(:fork)
      begin
        assert_nil LoadPathCache.load_path_cache
        cache = Tempfile.new("cache")
        pid = Process.fork do
          LoadPathCache.setup(cache_path: cache, development_mode: true, ignore_directories: nil)
          dir = File.realpath(Dir.mktmpdir)
          $LOAD_PATH.push(dir)
          FileUtils.touch("#{dir}/a.rb")
          stringish = mock
          stringish.expects(:to_str).returns("a").twice # bootsnap + ruby
          pathish = mock
          pathish.expects(:to_path).returns(stringish).twice # bootsnap + ruby
          assert pathish.respond_to?(:to_path)
          require(pathish)
          FileUtils.rm_rf(dir)
        end
        _, status = Process.wait2(pid)
        assert_predicate status, :success?
      ensure
        cache.close
        cache.unlink
      end
    end
  end

  class KernelLoadTest < Minitest::Test
    def setup
      @initial_dir = Dir.pwd
      @dir1 = File.realpath(Dir.mktmpdir)
      FileUtils.touch("#{@dir1}/a.rb")
      FileUtils.touch("#{@dir1}/no_ext")
      @dir2 = File.realpath(Dir.mktmpdir)
      File.binwrite("#{@dir2}/loads.rb", "load 'subdir/loaded'\nload './subdir/loaded'\n")
      FileUtils.mkdir("#{@dir2}/subdir")
      FileUtils.touch("#{@dir2}/subdir/loaded")
      $LOAD_PATH.push(@dir1)
    end

    def teardown
      $LOAD_PATH.pop
      Dir.chdir(@initial_dir)
      FileUtils.rm_rf(@dir1)
      FileUtils.rm_rf(@dir2)
    end

    def test_no_exstensions_for_kernel_load
      assert_raises(LoadError) { load "a" }
      assert(load("no_ext"))
      Dir.chdir(@dir2)
      assert(load("loads.rb"))
    end
  end
end
