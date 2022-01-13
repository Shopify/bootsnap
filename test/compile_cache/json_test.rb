# frozen_string_literal: true

require("test_helper")

class CompileCacheJSONTest < Minitest::Test
  include(TmpdirHelper)

  module FakeJson
    Fallback = Class.new(StandardError)
    class << self
      def load_file(_path, symbolize_names: false, freeze: false, fallback: nil)
        raise Fallback
      end
    end
  end

  def setup
    super
    Bootsnap::CompileCache::JSON.init!
    FakeJson.singleton_class.prepend(Bootsnap::CompileCache::JSON::Patch)
  end

  def test_json_input_to_output
    document = ::Bootsnap::CompileCache::JSON.input_to_output(<<~JSON, {})
      {
        "foo": 42,
        "bar": [1]
      }
    JSON
    expected = {
      "foo" => 42,
      "bar" => [1],
    }
    assert_equal expected, document
  end

  def test_load_file
    Help.set_file("a.json", '{"foo": "bar"}', 100)
    assert_equal({"foo" => "bar"}, FakeJson.load_file("a.json"))
  end

  def test_load_file_symbolize_names
    Help.set_file("a.json", '{"foo": "bar"}', 100)
    FakeJson.load_file("a.json")

    if ::Bootsnap::CompileCache::JSON.supported_options.include?(:symbolize_names)
      2.times do
        assert_equal({foo: "bar"}, FakeJson.load_file("a.json", symbolize_names: true))
      end
    else
      assert_raises(FakeJson::Fallback) do # would call super
        FakeJson.load_file("a.json", symbolize_names: true)
      end
    end
  end

  def test_load_file_freeze
    Help.set_file("a.json", '["foo"]', 100)
    FakeJson.load_file("a.json")

    if ::Bootsnap::CompileCache::JSON.supported_options.include?(:freeze)
      2.times do
        string = FakeJson.load_file("a.json", freeze: true).first
        assert_equal("foo", string)
        assert_predicate(string, :frozen?)
      end
    else
      assert_raises(FakeJson::Fallback) do # would call super
        FakeJson.load_file("a.json", freeze: true)
      end
    end
  end

  def test_load_file_unknown_option
    Help.set_file("a.json", '["foo"]', 100)
    FakeJson.load_file("a.json")

    assert_raises(FakeJson::Fallback) do # would call super
      FakeJson.load_file("a.json", fallback: true)
    end
  end
end
