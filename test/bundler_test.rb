require 'test_helper'

class BundlerTest < Minitest::Test
  def test_bundler?
    assert Bootsnap.bundler?
  end
end
