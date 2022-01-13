# frozen_string_literal: true

require("test_helper")

class CompileCacheISeqTest < Minitest::Test
  include(TmpdirHelper)

  def test_ruby_bug_18250
    Help.set_file("a.rb", "def foo(*); ->{ super }; end; def foo(**); ->{ super }; end", 100)
    Bootsnap::CompileCache::ISeq.fetch("a.rb")
  end
end
