require 'test_helper'

class BundlerTest < Minitest::Test
  def without_required_env_keys
    e = {}
    begin
      %w[BUNDLE_BIN_PATH BUNDLE_GEMFILE].each do |k|
        e[k] = ENV[k]
        ENV[k] = nil
      end
      yield
    ensure
      e.each { |k, v| ENV[k] = v }
    end
  end

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

  def without_bundler
    b = ::Bundler
    begin
      Object.send(:remove_const, :Bundler)
      yield
    ensure
      Object.send(:const_set, :Bundler, b)
    end
  end

  def test_bundler_without_bundler_const
    without_bundler do
      refute_predicate Bootsnap, :bundler?
    end
  end

  def test_bundler_without_required_env_keys
    without_required_env_keys do
      refute_predicate Bootsnap, :bundler?
    end
  end
end
