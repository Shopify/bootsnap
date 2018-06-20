require 'test_helper'

module Bootsnap
  module LoadPathCache
    class PathScannerTest < MiniTest::Test
      DLEXT = RbConfig::CONFIG['DLEXT']
      OTHER_DLEXT = DLEXT == 'bundle' ? 'so' : 'bundle'

      def test_scans_requirables_and_dirs
        Dir.mktmpdir do |dir|
          FileUtils.mkdir_p("#{dir}/ruby/a")
          FileUtils.mkdir_p("#{dir}/ruby/b/c")
          FileUtils.mkdir_p("#{dir}/support/h/i")
          FileUtils.mkdir_p("#{dir}/ruby/l")
          FileUtils.mkdir_p("#{dir}/support/l/m")
          FileUtils.touch("#{dir}/ruby/d.rb")
          FileUtils.touch("#{dir}/ruby/e.#{DLEXT}")
          FileUtils.touch("#{dir}/ruby/f.#{OTHER_DLEXT}")
          FileUtils.touch("#{dir}/ruby/a/g.rb")
          FileUtils.touch("#{dir}/support/h/j.rb")
          FileUtils.touch("#{dir}/support/h/i/k.rb")
          FileUtils.touch("#{dir}/support/l/m/n.rb")
          FileUtils.ln_s("#{dir}/support/h", "#{dir}/ruby/h")
          FileUtils.ln_s("#{dir}/support/l/m", "#{dir}/ruby/l/m")

          entries, dirs = PathScanner.call("#{dir}/ruby")
          assert_equal(["a/g.rb", "d.rb", "e.#{DLEXT}", "h/i/k.rb", "h/j.rb", "l/m/n.rb"], entries.sort)
          assert_equal(["a", "b", "b/c", "h", "h/i", "l", "l/m"], dirs.sort)
        end
      end
    end
  end
end
