# frozen_string_literal: true

require("test_helper")

class CompileCacheYAMLTest < Minitest::Test
  include(TmpdirHelper)

  module FakeYaml
    Fallback = Class.new(StandardError)
    class << self
      def load_file(_path, symbolize_names: false, freeze: false, fallback: nil)
        raise Fallback
      end

      def unsafe_load_file(_path, symbolize_names: false, freeze: false, fallback: nil)
        raise Fallback
      end
    end
  end

  def setup
    super
    Bootsnap::CompileCache::YAML.init!
    FakeYaml.singleton_class.prepend(Bootsnap::CompileCache::YAML.patch)
  end

  def test_yaml_strict_load
    document = ::Bootsnap::CompileCache::YAML.strict_load(<<~YAML)
      ---
      :foo: 42
      bar: [1]
    YAML
    expected = {
      foo: 42,
      "bar" => [1],
    }
    assert_equal expected, document
  end

  def test_yaml_tags
    error = assert_raises Bootsnap::CompileCache::YAML::UnsupportedTags do
      ::Bootsnap::CompileCache::YAML.strict_load("!many Boolean")
    end
    assert_equal "YAML tags are not supported: !many", error.message

    error = assert_raises Bootsnap::CompileCache::YAML::UnsupportedTags do
      ::Bootsnap::CompileCache::YAML.strict_load("!ruby/object {}")
    end
    assert_equal "YAML tags are not supported: !ruby/object", error.message
  end

  if YAML::VERSION >= "4"
    def test_load_psych_4_with_alias
      Help.set_file("a.yml", "foo: &foo\n  bar: 42\nplop:\n  <<: *foo", 100)

      foo = {"bar" => 42}
      expected = {"foo" => foo, "plop" => foo}
      assert_equal(expected, FakeYaml.unsafe_load_file("a.yml"))

      assert_raises Psych::BadAlias do
        FakeYaml.load_file("a.yml")
      end
    end

    def test_load_psych_4_with_unsafe_class
      Help.set_file("a.yml",  "---\nfoo: !ruby/regexp /bar/\n", 100)

      expected = {"foo" => /bar/}
      assert_equal(expected, FakeYaml.unsafe_load_file("a.yml"))

      assert_raises Psych::DisallowedClass do
        FakeYaml.load_file("a.yml")
      end
    end

    def test_yaml_input_to_output_safe
      document = ::Bootsnap::CompileCache::YAML::Psych4::SafeLoad.input_to_output(<<~YAML, {})
        ---
        :foo: 42
        bar: [1]
      YAML
      expected = {
        foo: 42,
        "bar" => [1],
      }
      assert_equal expected, document
    end

    def test_yaml_input_to_output_unsafe
      document = ::Bootsnap::CompileCache::YAML::Psych4::UnsafeLoad.input_to_output(<<~YAML, {})
        ---
        :foo: 42
        bar: [1]
      YAML
      expected = {
        foo: 42,
        "bar" => [1],
      }
      assert_equal expected, document
    end
  else
    def test_yaml_input_to_output
      document = ::Bootsnap::CompileCache::YAML::Psych3.input_to_output(<<~YAML, {})
        ---
        :foo: 42
        bar: [1]
      YAML
      expected = {
        foo: 42,
        "bar" => [1],
      }
      assert_equal expected, document
    end

    def test_load_file
      Help.set_file("a.yml", "---\nfoo: bar", 100)
      assert_equal({"foo" => "bar"}, FakeYaml.load_file("a.yml"))
    end

    def test_load_file_aliases
      Help.set_file("a.yml", "foo: &foo\n  bar: 42\nplop:\n  <<: *foo", 100)
      assert_equal({"foo" => {"bar" => 42}, "plop" => {"bar" => 42}}, FakeYaml.load_file("a.yml"))
    end

    def test_load_file_symbolize_names
      Help.set_file("a.yml", "---\nfoo: bar", 100)
      FakeYaml.load_file("a.yml")

      if ::Bootsnap::CompileCache::YAML.supported_options.include?(:symbolize_names)
        2.times do
          assert_equal({foo: "bar"}, FakeYaml.load_file("a.yml", symbolize_names: true))
        end
      else
        assert_raises(FakeYaml::Fallback) do # would call super
          FakeYaml.load_file("a.yml", symbolize_names: true)
        end
      end
    end

    def test_load_file_freeze
      Help.set_file("a.yml", "---\nfoo", 100)
      FakeYaml.load_file("a.yml")

      if ::Bootsnap::CompileCache::YAML.supported_options.include?(:freeze)
        2.times do
          string = FakeYaml.load_file("a.yml", freeze: true)
          assert_equal("foo", string)
          assert_predicate(string, :frozen?)
        end
      else
        assert_raises(FakeYaml::Fallback) do # would call super
          FakeYaml.load_file("a.yml", freeze: true)
        end
      end
    end

    def test_load_file_unknown_option
      Help.set_file("a.yml", "---\nfoo", 100)
      FakeYaml.load_file("a.yml")

      assert_raises(FakeYaml::Fallback) do # would call super
        FakeYaml.load_file("a.yml", fallback: true)
      end
    end
  end

  if YAML.respond_to?(:unsafe_load_file)
    def test_unsafe_load_file
      Help.set_file("a.yml", "foo: &foo\n  bar: 42\nplop:\n  <<: *foo", 100)
      assert_equal({"foo" => {"bar" => 42}, "plop" => {"bar" => 42}}, FakeYaml.unsafe_load_file("a.yml"))
    end
  end
end
