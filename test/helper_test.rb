# frozen_string_literal: true

require("test_helper")

class HelperTest < MiniTest::Test
  include(TmpdirHelper)

  def test_validate_cache_path
    path = Help.set_file("a.rb", "a = a = 3", 100)
    cp = Help.cache_path("#{@tmp_dir}-iseq", path)
    load(path)
    assert_equal(true, File.file?(cp))
  end
end
