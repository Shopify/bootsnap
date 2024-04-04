# frozen_string_literal: true

require "test_helper"
require "bootsnap/cli"

module Bootsnap
  class CLITest < Minitest::Test
    include TmpdirHelper

    def setup
      super
      @cache_dir = File.expand_path("tmp/cache/bootsnap/compile-cache")
    end

    def test_precompile_single_file
      skip_unless_iseq
      path = Help.set_file("a.rb", "a = a = 3", 100)
      CompileCache::ISeq.expects(:precompile).with(File.expand_path(path))
      assert_equal 0, CLI.new(["precompile", "-j", "0", path]).run
    end

    def test_precompile_rake_files
      skip_unless_iseq
      path = Help.set_file("a.rake", "a = a = 3", 100)
      CompileCache::ISeq.expects(:precompile).with(File.expand_path(path))
      assert_equal 0, CLI.new(["precompile", "-j", "0", path]).run
    end

    def test_precompile_rakefile
      skip_unless_iseq
      path = Help.set_file("Rakefile", "a = a = 3", 100)
      CompileCache::ISeq.expects(:precompile).with(File.expand_path(path))
      assert_equal 0, CLI.new(["precompile", "-j", "0", path]).run
    end

    def test_no_iseq
      skip_unless_iseq
      path = Help.set_file("a.rb", "a = a = 3", 100)
      CompileCache::ISeq.expects(:precompile).never
      assert_equal 0, CLI.new(["precompile", "-j", "0", "--no-iseq", path]).run
    end

    def test_precompile_directory
      skip_unless_iseq
      path_a = Help.set_file("foo/a.rb", "a = a = 3", 100)
      path_b = Help.set_file("foo/b.rb", "b = b = 3", 100)

      CompileCache::ISeq.expects(:precompile).with(File.expand_path(path_a))
      CompileCache::ISeq.expects(:precompile).with(File.expand_path(path_b))
      assert_equal 0, CLI.new(["precompile", "-j", "0", "foo"]).run
    end

    def test_precompile_exclude
      skip_unless_iseq
      path_a = Help.set_file("foo/a.rb", "a = a = 3", 100)
      Help.set_file("foo/b.rb", "b = b = 3", 100)

      CompileCache::ISeq.expects(:precompile).with(File.expand_path(path_a))
      assert_equal 0, CLI.new(["precompile", "-j", "0", "--exclude", "b.rb", "foo"]).run
    end

    def test_precompile_gemfile
      assert_equal 0, CLI.new(["precompile", "--gemfile"]).run
    end

    def test_precompile_yaml
      path = Help.set_file("a.yaml", "foo: bar", 100)
      CompileCache::YAML.expects(:precompile).with(File.expand_path(path))
      assert_equal 0, CLI.new(["precompile", "-j", "0", path]).run
    end

    def test_no_yaml
      path = Help.set_file("a.yaml", "foo: bar", 100)
      CompileCache::YAML.expects(:precompile).never
      assert_equal 0, CLI.new(["precompile", "-j", "0", "--no-yaml", path]).run
    end

    if Process.respond_to?(:fork)
      def test_version_flag
        read, write = IO.pipe
        # optparse --version immediately call exit so we test in a subprocess
        pid = fork do 
          STDOUT.reopen(write)
          read.close
          exit(CLI.new(["--version"]).run)
        end
        write.close

        _, status = Process.waitpid2(pid)
        assert_predicate status, :success?

        assert_includes read.read, Bootsnap::VERSION
      end
    end

    private

    def skip_unless_iseq
      skip("Unsupported platform") unless defined?(CompileCache::ISeq) && CompileCache::ISeq.supported?
    end
  end
end
