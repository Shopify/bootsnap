# frozen_string_literal: true
require('test_helper')
require('bootsnap/cli')

module Bootsnap
  class CLITest < Minitest::Test
    include(TmpdirHelper)

    def setup
      super
      @cache_dir = File.expand_path('tmp/cache/bootsnap/compile-cache')
    end

    def test_precompile_single_file
      path = Help.set_file('a.rb', 'a = a = 3', 100)
      CompileCache::ISeq.expects(:fetch).with(File.expand_path(path), cache_dir: @cache_dir)
      assert_equal 0, CLI.new(['precompile', path]).run
    end

    def test_precompile_directory
      path_a = Help.set_file('foo/a.rb', 'a = a = 3', 100)
      path_b = Help.set_file('foo/b.rb', 'b = b = 3', 100)

      CompileCache::ISeq.expects(:fetch).with(File.expand_path(path_a), cache_dir: @cache_dir)
      CompileCache::ISeq.expects(:fetch).with(File.expand_path(path_b), cache_dir: @cache_dir)
      assert_equal 0, CLI.new(['precompile', 'foo']).run
    end

    def test_precompile_exclude
      path_a = Help.set_file('foo/a.rb', 'a = a = 3', 100)
      Help.set_file('foo/b.rb', 'b = b = 3', 100)

      CompileCache::ISeq.expects(:fetch).with(File.expand_path(path_a), cache_dir: @cache_dir)
      assert_equal 0, CLI.new(['precompile', '--exclude', 'b.rb', 'foo']).run
    end

    def test_precompile_gemfile
      assert_equal 0, CLI.new(['precompile', '--gemfile']).run
    end
  end
end
