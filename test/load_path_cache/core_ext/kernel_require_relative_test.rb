# frozen_string_literal: true

require("test_helper")
require("bootsnap/load_path_cache")

module Bootsnap
  module KernelRequireRelativeTest
    class KernelRequireRelativeTest < MiniTest::Test
      def setup
        @initial_dir = Dir.pwd
        @dir1 = File.realpath(Dir.mktmpdir)

        Bootsnap::LoadPathCache.setup(
          cache_path: "#{@dir1}/cache",
          development_mode: true,
        )
        FileUtils.touch("#{@dir1}/a.rb")
        File.open("#{@dir1}/a.rb", "wb") { |f| f.write("require_relative 'b.rb'\n") }
        FileUtils.touch("#{@dir1}/b.rb")

        # Chaining a relative_require patch after bootsnap's
        Kernel.module_eval do
          alias_method :pre_patch_require_relative, :require_relative
          undef :require_relative
          def require_relative(path)
            pre_patch_require_relative(path)
          end
        end

      end

      def teardown
        FileUtils.rm_rf(@dir1)
        Kernel.module_eval do
          module_function

          undef :require_relative
          alias_method :require_relative, :pre_patch_require_relative
          undef :pre_patch_require_relative
        end
      end

      def test_chaining_require_relative
        assert(require("#{@dir1}/a.rb"))
      end
    end
  end
end
