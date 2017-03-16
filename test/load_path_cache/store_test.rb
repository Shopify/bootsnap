require 'test_helper'
require 'tmpdir'
require 'fileutils'

module Bootsnap
  module LoadPathCache
    class StoreTest < MiniTest::Test
      def setup
        @dir = Dir.mktmpdir
        @path = "#{@dir}/store"
        @store = Store.new(@path)
      end

      def teardown
        FileUtils.rm_rf(@dir)
      end

      attr_reader :store

      def test_persistence
        store.transaction { store.set('a', 'b') }

        store2 = Store.new(@path)
        assert_equal('b', store2.get('a'))
      end

      def test_modification
        store.transaction { store.set('a', 'b') }

        store2 = Store.new(@path)
        assert_equal('b', store2.get('a'))
        store.transaction { store.set('a', 'c') }

        store3 = Store.new(@path)
        assert_equal('c', store3.get('a'))
      end

      def test_stores_arrays
        store.transaction { store.set('a', [1234, %w(a b)]) }

        store2 = Store.new(@path)
        assert_equal([1234, %w(a b)], store2.get('a'))
      end

      def test_transaction_required_to_set
        assert_raises(Store::SetOutsideTransactionNotAllowed) do
          store.set('a', 'b')
        end
        assert_raises(Store::SetOutsideTransactionNotAllowed) do
          store.fetch('a') { 'b' }
        end
      end

      def test_nested_transaction_fails
        assert_raises(Store::NestedTransactionError) do
          store.transaction { store.transaction }
        end
      end

      def test_no_commit_unless_dirty
        store.transaction { store.set('a', nil) }
        refute File.exist?(@path)
        store.transaction { store.set('a', 1) }
        assert File.exist?(@path)
      end
    end
  end
end
