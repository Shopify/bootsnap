# frozen_string_literal: true

require("test_helper")

module Bootsnap
  module LoadPathCache
    class ChangeObserverTest < MiniTest::Test
      def setup
        @observer = Object.new
        @arr = []
        ChangeObserver.register(@observer, @arr)
      end

      def test_observes_changes
        @observer.expects(:push_paths).with(@arr, "a")
        @arr << "a"

        @observer.expects(:push_paths).with(@arr, "b", "c")
        @arr.push("b", "c")

        @observer.expects(:push_paths).with(@arr, "d", "e")
        @arr.append("d", "e")

        @observer.expects(:unshift_paths).with(@arr, "f", "g")
        @arr.unshift("f", "g")

        @observer.expects(:push_paths).with(@arr, "h", "i")
        @arr.concat(%w(h i))

        @observer.expects(:unshift_paths).with(@arr, "j", "k")
        @arr.prepend("j", "k")
      end

      def test_reinitializes_on_aggressive_modifications
        @observer.expects(:push_paths).with(@arr, "a", "b", "c")
        @arr.push("a", "b", "c")

        @observer.expects(:reinitialize).times(4)
        @arr.delete(3)
        @arr.compact!
        @arr.map!(&:upcase)
        assert_equal("C", @arr.pop)
        assert_equal(%w(A B), @arr)
      end

      def test_register_frozen
        # just assert no crash
        ChangeObserver.register(@observer, @arr.dup.freeze)
      end

      def test_register_twice_observes_once
        ChangeObserver.register(@observer, @arr)

        @observer.expects(:push_paths).with(@arr, "a").once
        @arr << "a"
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
