$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'aot_compile_cache'

require 'minitest/autorun'
require 'mocha/mini_test'

require 'tmpdir'
require 'fileutils'

module TmpdirHelper
  def setup
    super
    @prev_dir = Dir.pwd
    @tmp_dir = Dir.mktmpdir('aotcc-test')
    Dir.chdir(@tmp_dir)
  end

  def teardown
    super
    Dir.chdir(@prev_dir)
    FileUtils.remove_entry(@tmp_dir)
  end
end
