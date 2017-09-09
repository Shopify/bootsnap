require 'test_helper'

class PreprocessorTest < Minitest::Test
  class NumberSigilPreprocessor
    def call(contents, _)
      contents.gsub(%r{~n\(([\d\s+-/*\(\)]+?)\)}) do |match|
        eval(match[3..-2])
      end
    end
  end

  class << self
    attr_accessor :response
  end

  def test_iseq
    with_preprocessor do
      contents = "PreprocessorTest.response = ~n(1 + 2)"
      storage = Bootsnap::CompileCache::ISeq.input_to_storage(contents, nil)
      output = Bootsnap::CompileCache::ISeq.storage_to_output(storage)

      self.class.response = nil
      output.eval
      assert_equal 3, self.class.response
    end
  end

  private

  def with_preprocessor
    previous = Bootsnap::CompileCache::ISeq.preprocessor
    Bootsnap::CompileCache::ISeq.preprocessor = NumberSigilPreprocessor.new
    yield
    Bootsnap::CompileCache::ISeq.preprocessor = previous
  end
end
