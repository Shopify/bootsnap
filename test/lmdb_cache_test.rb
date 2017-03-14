require 'test_helper'

module Bootsnap
  module LMDBCache
    class StoreTest < MiniTest::Test
      def setup
        @dir = Dir.mktmpdir
        @store = LMDBCache::Store.new(@dir)
      end

      def teardown
        FileUtils.rm_r(@dir) if File.exist?(@dir)
      end

      def test_accessible_by_multiple_instances
        clone = LMDBCache::Store.new(@dir)
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

    class LRUStoreTest < MiniTest::Test
      def setup
        @dir = Dir.mktmpdir
        @store = LMDBCache::LRUStore.new(@dir, max_size: 4)
      end

      def teardown
        FileUtils.rm_r(@dir) if File.exist?(@dir)
      end

      def test_gc
        @store.set('a', 1)
        @store.set('b', 1)
        @store.set('c', 1)
        @store.set('d', 1)
        @store.set('e', 1)
        @store.set('f', 1)
        @store.delete('b')
        @store.gc
        assert_nil @store.get('a')
        assert_nil @store.get('b')
        assert_equal @store.get('d'), 1
        assert_equal @store.get('d'), 1
        assert_equal @store.get('e'), 1
        assert_equal @store.get('f'), 1
      end

      def test_automatic_gc
        9.times do |i|
          @store.set(i.to_s, 1)
        end
        assert_equal 6, @store.size
      end
    end
  end
end
