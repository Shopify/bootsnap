# frozen_string_literal: true
require('test_helper')

class CompileCacheYAMLTest < Minitest::Test
  include(TmpdirHelper)

  module FakeYaml
    Fallback = Class.new(StandardError)
    extend self
    singleton_class.prepend(Bootsnap::CompileCache::YAML::Patch)

    def load_file(path, symbolize_names: false, freeze: false, fallback: nil)
      raise Fallback
    end
  end

  def setup
    super
    Bootsnap::CompileCache::YAML.init!
  end

  def test_yaml_strict_load
    document = ::Bootsnap::CompileCache::YAML.strict_load(<<~YAML)
      ---
      :foo: 42
      bar: [1]
    YAML
    expected = {
      foo: 42,
      'bar' => [1],
    }
    assert_equal expected, document
  end

  def test_yaml_tags
    error = assert_raises Bootsnap::CompileCache::Uncompilable do
      ::Bootsnap::CompileCache::YAML.strict_load('!many Boolean')
    end
    assert_equal "YAML tags are not supported: !many", error.message

    error = assert_raises Bootsnap::CompileCache::Uncompilable do
      ::Bootsnap::CompileCache::YAML.strict_load('!ruby/object {}')
    end
    assert_equal "YAML tags are not supported: !ruby/object", error.message
  end

  def test_load_file
    Help.set_file('a.yml', "---\nfoo: bar", 100)
    assert_equal({'foo' => 'bar'}, FakeYaml.load_file('a.yml'))
  end

  def test_load_file_symbolize_names
    Help.set_file('a.yml', "---\nfoo: bar", 100)
    FakeYaml.load_file('a.yml')

    if ::Bootsnap::CompileCache::YAML.supported_options.include?(:symbolize_names)
      2.times do
        assert_equal({foo: 'bar'}, FakeYaml.load_file('a.yml', symbolize_names: true))
      end
    else
      assert_raises(FakeYaml::Fallback) do # would call super
        FakeYaml.load_file('a.yml', symbolize_names: true)
      end
    end
  end

  def test_load_file_freeze
    Help.set_file('a.yml', "---\nfoo", 100)
    FakeYaml.load_file('a.yml')

    if ::Bootsnap::CompileCache::YAML.supported_options.include?(:freeze)
      2.times do
        string = FakeYaml.load_file('a.yml', freeze: true)
        assert_equal("foo", string)
        assert_predicate(string, :frozen?)
      end
    else
      assert_raises(FakeYaml::Fallback) do # would call super
        FakeYaml.load_file('a.yml', freeze: true)
      end
    end
  end

  def test_load_file_unknown_option
    Help.set_file('a.yml', "---\nfoo", 100)
    FakeYaml.load_file('a.yml')

    assert_raises(FakeYaml::Fallback) do # would call super
      FakeYaml.load_file('a.yml', fallback: true)
    end
  end

  def test_ignore_read_only_filesystem
    Help.set_file('a.yml', "---\nfoo", 100)
    Bootsnap::CompileCache::Native.expects(:fetch).raises(Errno::EROFS.new("Read-only file system @ rb_sysopen"))
    Bootsnap::CompileCache::YAML.install!(Bootsnap::CompileCache::YAML.cache_dir)
    document = ::YAML.load_file('a.yml')
  end
end
