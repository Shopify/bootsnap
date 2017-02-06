$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'bootsnap'

require 'minitest/autorun'
require 'mocha/mini_test'

require 'tmpdir'
require 'fileutils'

module TmpdirHelper
  def setup
    super
    @prev_dir = Dir.pwd
    @tmp_dir = Dir.mktmpdir('bootsnap-test')
    Dir.chdir(@tmp_dir)
  end

  def teardown
    super
    Dir.chdir(@prev_dir)
    FileUtils.remove_entry(@tmp_dir)
  end
end
