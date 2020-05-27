# frozen_string_literal: true
require('test_helper')

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

      def test_path_exclusion
        Dir.mktmpdir do |dir|
          excluded_paths = [
            File.join(dir, 'node_modules'),
            File.join(dir, 'tmp', 'cache'),
            File.join(dir, 'excludeme.rb'),
            File.join(dir, 'excludemetoo.rb')
          ]

          %w[ruby/tmp/cache tmp/in_temp tmp/cache node_modules].each do |directory|
            FileUtils.mkdir_p(File.join(dir, directory))
          end

          FileUtils.touch("#{dir}/ruby/a")
          FileUtils.touch("#{dir}/ruby/d.rb")
          FileUtils.touch("#{dir}/bundle.rb")
          FileUtils.touch("#{dir}/excludeme.rb")
          FileUtils.touch("#{dir}/tmp/in_temp/tmp.rb")
          FileUtils.touch("#{dir}/tmp/cache/tmp.rb")
          FileUtils.touch("#{dir}/ruby/tmp/cache/tmp.rb")
          FileUtils.touch("#{dir}/node_modules/d.rb")

          entries, dirs = PathScanner.call(dir, excluded_paths: excluded_paths)
          assert_equal(%w[bundle.rb ruby/d.rb ruby/tmp/cache/tmp.rb tmp/in_temp/tmp.rb], entries.sort)
          assert_equal(%w[ruby ruby/tmp ruby/tmp/cache tmp tmp/in_temp], dirs.sort)
        end
      end
    end
  end
end
