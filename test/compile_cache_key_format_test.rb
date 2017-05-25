require 'test_helper'
require 'tempfile'
require 'tmpdir'
require 'fileutils'

class CompileCacheKeyFormatTest < Minitest::Test
  include TmpdirHelper

  R = {
    version:        0...4,
    os_version:     4...8,
    compile_option: 8...12,
    ruby_revision:  12...16,
    size:           16...24,
    mtime:          24...32,
    data_size:      32...40,
  }

  def test_key_version
    key = cache_key_for_file(__FILE__)
    exp = [2].pack("L")
    assert_equal(exp, key[R[:version]])
  end

  def test_key_compile_option_stable
    k1 = cache_key_for_file(__FILE__)
    k2 = cache_key_for_file(__FILE__)
    RubyVM::InstructionSequence.compile_option = { tailcall_optimization: true }
    k3 = cache_key_for_file(__FILE__)
    assert_equal(k1[R[:compile_option]], k2[R[:compile_option]])
    refute_equal(k1[R[:compile_option]], k3[R[:compile_option]])
  ensure
    RubyVM::InstructionSequence.compile_option = { tailcall_optimization: false }
  end

  def test_key_ruby_revision
    key = cache_key_for_file(__FILE__)
    exp = [RUBY_REVISION].pack("L")
    assert_equal(exp, key[R[:ruby_revision]])
  end

  def test_key_size
    key = cache_key_for_file(__FILE__)
    exp = File.size(__FILE__)
    act = key[R[:size]].unpack("Q")[0]
    assert_equal(exp, act)
  end

  def test_key_mtime
    key = cache_key_for_file(__FILE__)
    exp = File.mtime(__FILE__).to_i
    act = key[R[:mtime]].unpack("Q")[0]
    assert_equal(exp, act)
  end

  def test_fetch
    actual = Bootsnap::CompileCache::Native.fetch(@tmp_dir, '/dev/null', TestHandler)
    assert_equal('NEATO /DEV/NULL', actual)
    data = File.read("#{@tmp_dir}/8c/d2d180bbd995df")
    assert_match(%r{.{64}neato /dev/null}, data.force_encoding(Encoding::BINARY))
    actual = Bootsnap::CompileCache::Native.fetch(@tmp_dir, '/dev/null', TestHandler)
    assert_equal('NEATO /DEV/NULL', actual)
  end

  private

  def cache_key_for_file(file)
    Bootsnap::CompileCache::Native.fetch(@tmp_dir, file, TestHandler)
    data = File.read(Help.cache_path(@tmp_dir, file))
    Help.binary(data[0..31])
  end
end
