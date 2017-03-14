require 'test_helper'

module BootLib
  module LoadPathCache
    class ChangeObserverTest < ActiveSupport::TestCase
      def setup
        @observer = Object.new
        @arr = []
        ChangeObserver.register(@observer, @arr)
      end

      def test_observes_changes
        @observer.expects(:push_paths).with('a')
        @arr << 'a'

        @observer.expects(:push_paths).with('b', 'c')
        @arr.push('b', 'c')

        @observer.expects(:unshift_paths).with('d', 'e')
        @arr.unshift('d', 'e')

        @observer.expects(:push_paths).with('f', 'g')
        @arr.concat(['f', 'g'])

        assert_raises(NotImplementedError) { @arr + [] }
        assert_raises(NotImplementedError) { @arr.map!(&:foo) }
        assert_raises(NotImplementedError) { @arr.delete }

        assert_equal(%w(d e a b c f g), @arr)
      end
    end
  end
end
