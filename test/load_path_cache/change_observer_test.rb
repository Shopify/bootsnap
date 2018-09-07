require 'test_helper'

module Bootsnap
  module LoadPathCache
    class ChangeObserverTest < MiniTest::Test
      def setup
        @observer = Object.new
        @arr = []
        ChangeObserver.register(@observer, @arr)
      end

      def test_observes_changes
        @observer.expects(:push_paths).with(@arr, 'a')
        @arr << 'a'

        @observer.expects(:push_paths).with(@arr, 'b', 'c')
        @arr.push('b', 'c')

        @observer.expects(:unshift_paths).with(@arr, 'd', 'e')
        @arr.unshift('d', 'e')

        @observer.expects(:push_paths).with(@arr, 'f', 'g')
        @arr.concat(%w(f g))

        @observer.expects(:reinitialize).times(4)
        @arr.delete(3)
        @arr.compact!
        @arr.map!(&:upcase)
        assert_equal('G', @arr.pop)
        assert_equal(%w(D E A B C F), @arr)
      end

      def test_register_twice_observes_once
        ChangeObserver.register(@observer, @arr)

        @observer.expects(:push_paths).with(@arr, 'a').once
        @arr << 'a'
        assert_equal(%w(a), @arr)
      end

      def test_uniq_without_block
        @observer.expects(:reinitialize).never
        @arr.uniq!
      end

      def test_uniq_with_block
        @observer.expects(:reinitialize).once
        @arr.uniq! {}
      end
    end
  end
end
