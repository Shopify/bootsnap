require 'test_helper'

class BundlerTest < Minitest::Test
  def test_bundler_with_bundle_bin_path_env
    without_required_env_keys do
      ENV['BUNDLE_BIN_PATH'] = 'foo'
      assert_predicate Bootsnap, :bundler?
    end
  end

  def test_bundler_with_bundle_gemfile_env
    without_required_env_keys do
      ENV['BUNDLE_GEMFILE'] = 'foo'
      assert_predicate Bootsnap, :bundler?
    end
  end

  def test_bundler_without_bundler_const
    without_bundler do
      refute_predicate Bootsnap, :bundler?
    end
  end

  def test_bundler_without_required_env_keys
    without_required_env_keys do
      assert defined?(::Bundler)
      refute_predicate Bootsnap, :bundler?
    end
  end

  private

  def without_bundler
    b = ::Bundler
    begin
      Object.send(:remove_const, :Bundler)
      yield
    ensure
      Object.send(:const_set, :Bundler, b)
    end
  end

  def without_required_env_keys
    original_env = {}
    begin
      %w(BUNDLE_BIN_PATH BUNDLE_GEMFILE).each do |k|
        original_env[k] = ENV[k]
        ENV[k] = nil
      end
      yield
    ensure
      original_env.each { |k, v| ENV[k] = v }
    end
  end
end
