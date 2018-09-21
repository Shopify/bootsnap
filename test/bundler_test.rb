require 'test_helper'

class BundlerTest < Minitest::Test
  def test_bundler?
    assert Bootsnap.bundler?
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

  def test_bundler_when_Bundler_const_not_defined
    without_bundler do
      refute_predicate Bootsnap, :bundler?
    end
  end
end
