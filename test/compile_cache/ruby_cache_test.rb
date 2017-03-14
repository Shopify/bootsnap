require 'test_helper'

require 'bootsnap/compile_cache/ruby_cache'

module Bootsnap
  module CompileCache
    class RubyCacheTest < MiniTest::Test
      def test_it_works
        cache = RubyCache.new(NullCache)
        iseq = cache.fetch(__FILE__)
        assert_instance_of(RubyVM::InstructionSequence, iseq)
      end
    end
  end
end
