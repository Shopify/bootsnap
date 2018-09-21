require 'test_helper'

class BundlerTest < Minitest::Test
  def test_bundler?
    assert Bootsnap.bundler?
  end

  def test_bundler_when_Bundler_undefined
    Object.send(:remove_const, :Bundler)
    refute Bootsnap.bundler?
    require 'bundler'
  end
end
