module Bootsnap
  module LoadPathCache
    class PathScannerTest < MiniTest::Test
      DLEXT = RbConfig::CONFIG['DLEXT']
      OTHER_DLEXT = DLEXT == 'bundle' ? 'so' : 'bundle'

      def test_scans_requirables_and_dirs
        Dir.mktmpdir do |dir|
          FileUtils.mkdir("#{dir}/a")
          FileUtils.mkdir("#{dir}/b")
          FileUtils.mkdir("#{dir}/b/c")
          FileUtils.touch("#{dir}/d.rb")
          FileUtils.touch("#{dir}/e.#{DLEXT}")
          FileUtils.touch("#{dir}/f.#{OTHER_DLEXT}")
          FileUtils.touch("#{dir}/a/g.rb")

          entries, dirs = PathScanner.call(dir)
          assert_equal(["a/g.rb", "d.rb", "e.#{DLEXT}"], entries.sort)
          assert_equal(["a", "b", "b/c"], dirs.sort)
        end
      end
    end
  end
end
