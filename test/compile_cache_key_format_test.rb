# frozen_string_literal: true

require("test_helper")
require("tempfile")
require("tmpdir")
require("fileutils")

class CompileCacheKeyFormatTest < Minitest::Test
  FILE = File.expand_path(__FILE__)
  include(TmpdirHelper)

  R = {
    version: 0...4,
    ruby_platform: 4...8,
    compile_option: 8...12,
    ruby_revision: 12...16,
    size: 16...24,
    mtime: 24...32,
    data_size: 32...40,
  }.freeze

  def test_key_version
    key = cache_key_for_file(FILE)
    exp = [4].pack("L")
    assert_equal(exp, key[R[:version]])
  end

  def test_key_compile_option_stable
    k1 = cache_key_for_file(FILE)
    k2 = cache_key_for_file(FILE)
    RubyVM::InstructionSequence.compile_option = {tailcall_optimization: true}
    k3 = cache_key_for_file(FILE)
    assert_equal(k1[R[:compile_option]], k2[R[:compile_option]])
    refute_equal(k1[R[:compile_option]], k3[R[:compile_option]])
  ensure
    RubyVM::InstructionSequence.compile_option = {tailcall_optimization: false}
  end

  def test_key_ruby_revision
    key = cache_key_for_file(FILE)
    exp = if RUBY_REVISION.is_a?(String)
      [Help.fnv1a_64(RUBY_REVISION) >> 32].pack("L")
    else
      [RUBY_REVISION].pack("L")
    end
    assert_equal(exp, key[R[:ruby_revision]])
  end

  def test_key_size
    key = cache_key_for_file(FILE)
    exp = File.size(FILE)
    act = key[R[:size]].unpack1("Q")
    assert_equal(exp, act)
  end

  def test_key_mtime
    key = cache_key_for_file(FILE)
    exp = File.mtime(FILE).to_i
    act = key[R[:mtime]].unpack1("Q")
    assert_equal(exp, act)
  end

  def test_fetch
    if RbConfig::CONFIG["host_os"] =~ /mswin|mingw|cygwin/
      target = "NUL"
      expected_file = "#{@tmp_dir}/36/9eba19c29ffe00"
    else
      target = "/dev/null"
      expected_file = "#{@tmp_dir}/8c/d2d180bbd995df"
    end

    actual = Bootsnap::CompileCache::Native.fetch(@tmp_dir, target, TestHandler, nil)
    assert_equal("NEATO #{target.upcase}", actual)

    data = File.read(expected_file)
    assert_equal("neato #{target}", data.force_encoding(Encoding::BINARY)[64..-1])

    actual = Bootsnap::CompileCache::Native.fetch(@tmp_dir, target, TestHandler, nil)
    assert_equal("NEATO #{target.upcase}", actual)
  end

  def test_unexistent_fetch
    assert_raises(Errno::ENOENT) do
      Bootsnap::CompileCache::Native.fetch(@tmp_dir, "123", Bootsnap::CompileCache::ISeq, nil)
    end
  end

  private

  def cache_key_for_file(file)
    Bootsnap::CompileCache::Native.fetch(@tmp_dir, file, TestHandler, nil)
    data = File.binread(Help.cache_path(@tmp_dir, file))
    data.byteslice(0..31)
  end
end
