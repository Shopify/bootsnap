require 'test_helper'

module Bootsnap
  module LoadPathCache
    class LoadedFeaturesIndexTest < MiniTest::Test
      def setup
        @index = LoadedFeaturesIndex.new
        # not really necessary but let's just make it a clean slate
        @index.instance_variable_set(:@lfi, {})
      end

      def test_successful_addition
        refute @index.key?('bundler')
        refute @index.key?('bundler.rb')
        refute @index.key?('foo')
        @index.register('bundler', '/a/b/bundler.rb') {}
        assert @index.key?('bundler')
        assert @index.key?('bundler.rb')
        refute @index.key?('foo')
      end

      def test_no_add_on_raise
        refute @index.key?('bundler')
        refute @index.key?('bundler.rb')
        refute @index.key?('foo')
        assert_raises(RuntimeError) do
          @index.register('bundler', '/a/b/bundler.rb') { raise }
        end
        refute @index.key?('bundler')
        refute @index.key?('bundler.rb')
        refute @index.key?('foo')
      end

      def test_infer_base_from_ext
        refute @index.key?('bundler')
        refute @index.key?('bundler.rb')
        refute @index.key?('foo')
        @index.register('bundler.rb') {}
        assert @index.key?('bundler')
        assert @index.key?('bundler.rb')
        refute @index.key?('foo')
      end

      def test_cannot_infer_ext_from_base # Current limitation
        refute @index.key?('bundler')
        refute @index.key?('bundler.rb')
        refute @index.key?('foo')
        @index.register('bundler') {}
        assert @index.key?('bundler')
        refute @index.key?('bundler.rb')
        refute @index.key?('foo')
      end

      def test_derives_initial_state_from_loaded_features
        index = LoadedFeaturesIndex.new
        assert index.key?('minitest/autorun')
        assert index.key?('minitest/autorun.rb')
        refute index.key?('minitest/autorun.so')
      end
    end
  end
end
