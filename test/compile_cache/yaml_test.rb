# frozen_string_literal: true
require('test_helper')

class CompileCacheYAMLTest < Minitest::Test
  include(TmpdirHelper)

  def setup
    super
    Bootsnap::CompileCache::YAML.init!
  end

  def test_load_file
    Help.set_file('a.yml', "---\nfoo: bar", 100)
    assert_equal({'foo' => 'bar'}, Bootsnap::CompileCache::YAML::Patch.load_file('a.yml'))
  end

  def test_load_file_symbolize_names
    Help.set_file('a.yml', "---\nfoo: bar", 100)
    Bootsnap::CompileCache::YAML::Patch.load_file('a.yml')

    if ::Bootsnap::CompileCache::YAML.supported_options.include?(:symbolize_names)
      2.times do
        assert_equal({foo: 'bar'}, Bootsnap::CompileCache::YAML::Patch.load_file('a.yml', symbolize_names: true))
      end
    else
      assert_raises(NoMethodError) do # would call super
        Bootsnap::CompileCache::YAML::Patch.load_file('a.yml', symbolize_names: true)
      end
    end
  end

  def test_load_file_freeze
    Help.set_file('a.yml', "---\nfoo", 100)
    Bootsnap::CompileCache::YAML::Patch.load_file('a.yml')

    if ::Bootsnap::CompileCache::YAML.supported_options.include?(:freeze)
      2.times do
        string = Bootsnap::CompileCache::YAML::Patch.load_file('a.yml', freeze: true)
        assert_equal("foo", string)
        assert_predicate(string, :frozen?)
      end
    else
      assert_raises(NoMethodError) do # would call super
        Bootsnap::CompileCache::YAML::Patch.load_file('a.yml', freeze: true)
      end
    end
  end

  def test_load_file_unknown_option
    Help.set_file('a.yml', "---\nfoo", 100)
    Bootsnap::CompileCache::YAML::Patch.load_file('a.yml')

    assert_raises(NoMethodError) do # would call super
      Bootsnap::CompileCache::YAML::Patch.load_file('a.yml', unknown: true)
    end
  end
end
