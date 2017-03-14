require 'test_helper'

module Bootsnap
  class LMDBCacheTest < MiniTest::Test
    def setup
      @dir = Dir.mktmpdir
      @store = LMDBCache.new(@dir, msgpack: true)
    end

    def teardown
      FileUtils.rm_r(@dir) if File.exist?(@dir)
    end

    def test_accessible_by_multiple_instances
      clone = LMDBCache.new(@dir, msgpack: true)
      @store.set('a', 1)
      assert_equal 1, clone.get('a')
      @store.set('a', 2)
      assert_equal 2, clone.get('a')
    end

    def test_acts_as_a_key_value_store
      assert_nil @store.get('a')
      @store.set('a', 1)
      assert_equal 1, @store.get('a')
    end

    def test_fetch
      obj = Object.new
      obj.expects(:foo).once.returns(42)
      assert_equal(42, @store.fetch('a') { obj.foo })
      assert_equal(42, @store.fetch('a') { obj.foo })
    end
  end
end
