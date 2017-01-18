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
        @arr.concat(['f', 'g'])

        @observer.expects(:reinitialize).times(3)
        @arr.delete(3)
        @arr.compact!
        @arr.map!(&:foo)

        assert_equal(%w(d e a b c f g), @arr)
      end
    end
  end
end
