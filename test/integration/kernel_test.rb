# frozen_string_literal: true

require("test_helper")

module Bootsnap
  class KernelTest < Minitest::Test
    include TmpdirHelper

    def test_require_symlinked_file_twice
      setup_symlinked_files
      if RUBY_VERSION >= "3.1"
        # Fixed in https://github.com/ruby/ruby/commit/79a4484a072e9769b603e7b4fbdb15b1d7eccb15 (Ruby 3.1)
        assert_both_pass(<<~RUBY)
          require "symlink/test"
          require "real/test"
        RUBY
      else
        assert_both_pass(<<~RUBY)
          require "symlink/test"
          begin
            require "real/test"
          rescue RuntimeError
            exit 0
          else
            exit 1
          end
        RUBY
      end
    end

    def test_require_symlinked_file_twice_aliased
      setup_symlinked_files
      assert_both_pass(<<~RUBY)
        $LOAD_PATH.unshift(File.expand_path("symlink"))
        require "test"

        $LOAD_PATH.unshift(File.expand_path("a"))
        require "test"
      RUBY
    end

    def test_require_relative_symlinked_file_twice
      setup_symlinked_files
      if RUBY_VERSION >= "3.1"
        # Fixed in https://github.com/ruby/ruby/commit/79a4484a072e9769b603e7b4fbdb15b1d7eccb15 (Ruby 3.1)
        assert_both_pass(<<~RUBY)
          require_relative "symlink/test"
          require_relative "real/test"
        RUBY
      else
        assert_both_pass(<<~RUBY)
          require_relative "symlink/test"
          begin
            require_relative "real/test"
          rescue RuntimeError
            exit 0
          else
            exit 1
          end
        RUBY
      end
    end

    def test_require_and_then_require_relative_symlinked_file
      setup_symlinked_files
      assert_both_pass(<<~RUBY)
        $LOAD_PATH.unshift(File.expand_path("symlink"))
        require "test"

        require_relative "real/test"
      RUBY
    end

    def test_require_relative_and_then_require_symlinked_file
      setup_symlinked_files
      assert_both_pass(<<~RUBY)
        require_relative "real/test"

        $LOAD_PATH.unshift(File.expand_path("symlink"))
        require "test"
      RUBY
    end

    def test_require_deep_symlinked_file_twice
      setup_symlinked_files
      if RUBY_VERSION >= "3.1"
        # Fixed in https://github.com/ruby/ruby/commit/79a4484a072e9769b603e7b4fbdb15b1d7eccb15 (Ruby 3.1)
        assert_both_pass(<<~RUBY)
          require "symlink/dir/deep"
          require "real/dir/deep"
        RUBY
      else
        assert_both_pass(<<~RUBY)
          require "symlink/dir/deep"
          begin
            require "real/dir/deep"
          rescue RuntimeError
            exit 0
          else
            exit 1
          end
        RUBY
      end
    end

    def test_require_deep_symlinked_file_twice_aliased
      setup_symlinked_files
      assert_both_pass(<<~RUBY)
        $LOAD_PATH.unshift(File.expand_path("symlink"))
        require "dir/deep"

        $LOAD_PATH.unshift(File.expand_path("a"))
        require "dir/deep"
      RUBY
    end

    def test_require_relative_deep_symlinked_file_twice
      setup_symlinked_files
      if RUBY_VERSION >= "3.1"
        # Fixed in https://github.com/ruby/ruby/commit/79a4484a072e9769b603e7b4fbdb15b1d7eccb15 (Ruby 3.1)
        assert_both_pass(<<~RUBY)
          require_relative "symlink/dir/deep"
          require_relative "real/dir/deep"
        RUBY
      else
        assert_both_pass(<<~RUBY)
          require_relative "symlink/dir/deep"
          begin
            require_relative "real/dir/deep"
          rescue RuntimeError
            exit 0
          else
            exit 1
          end
        RUBY
      end
    end

    def test_require_and_then_require_relative_deep_symlinked_file
      setup_symlinked_files
      assert_both_pass(<<~RUBY)
        $LOAD_PATH.unshift(File.expand_path("symlink"))
        require "dir/deep"

        require_relative "real/dir/deep"
      RUBY
    end

    def test_require_relative_and_then_require_deep_symlinked_file
      setup_symlinked_files
      assert_both_pass(<<~RUBY)
        require_relative "real/dir/deep"

        $LOAD_PATH.unshift(File.expand_path("symlink"))
        require "dir/deep"
      RUBY
    end

    private

    def assert_both_pass(source)
      Help.set_file("without_bootsnap.rb", source)
      unless execute("without_bootsnap.rb", "debug.txt")
        flunk "expected snippet to pass WITHOUT bootsnap enabled:\n#{debug_output}"
      end

      Help.set_file("with_bootsnap.rb", %{require "bootsnap/setup"\n#{source}})
      unless execute("with_bootsnap.rb", "debug.txt")
        flunk "expected snippet to pass WITH bootsnap enabled:\n#{debug_output}"
      end
    end

    def debug_output
      File.read("debug.txt")
    rescue Errno::ENOENT
    end

    def execute(script_path, output_path)
      system(
        {"BOOTSNAP_CACHE_DIR" => "tmp/cache"},
        RbConfig.ruby, "-I.", script_path,
        out: output_path, err: output_path
      )
    end

    def assert_successful(source)
      Help.set_file("test_case.rb", source)

      Help.set_file("test_case.rb", %{require "bootsnap/setup"\n#{source}})
      assert system({"BOOTSNAP_CACHE_DIR" => "tmp/cache"}, RbConfig.ruby, "-Ilib:.", "test_case.rb")
    end

    def setup_symlinked_files
      skip("Platform doesn't support symlinks") unless File.respond_to?(:symlink)

      Help.set_file("real/test.rb", <<-RUBY)
        if $test_already_required
          raise "test.rb required more than once"
        else
          $test_already_required = true
        end
      RUBY

      Help.set_file("real/dir/deep.rb", <<-RUBY)
        if $deep_already_required
          raise "deep.rb required more than once"
        else
          $deep_already_required = true
        end
      RUBY
      File.symlink("real", "symlink")
    end
  end
end
