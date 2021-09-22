# frozen_string_literal: true
require('test_helper')

module Bootsnap
  module KernelRequireTest
    class KernelLoadTest < MiniTest::Test
      def setup
        @initial_dir = Dir.pwd
        @dir1 = File.realpath(Dir.mktmpdir)
        FileUtils.touch("#{@dir1}/a.rb")
        FileUtils.touch("#{@dir1}/no_ext")
        @dir2 = File.realpath(Dir.mktmpdir)
        File.open("#{@dir2}/loads.rb", "wb") { |f| f.write("load 'subdir/loaded'\nload './subdir/loaded'\n") }
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
        assert_raises(LoadError) { load 'a' }
        assert(load 'no_ext')
        Dir.chdir(@dir2)
        assert(load 'loads.rb')
      end
    end
  end
end
