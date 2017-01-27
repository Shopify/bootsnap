require 'test_helper'

require 'aot_compile_cache/iseq'

class AOTCompileCacheTest < Minitest::Test
  include TmpdirHelper

  def test_that_it_has_a_version_number
    refute_nil ::AOTCompileCache::VERSION
  end

  def test_file_is_only_read_once
    path = set_file('a.rb', 'a = 3', 100)
    storage = RubyVM::InstructionSequence.compile_file(path).to_binary
    output = RubyVM::InstructionSequence.load_from_binary(storage)
    # This doesn't really *prove* the file is only read once, but
    # it at least asserts the input is only cached once.
    AOTCompileCache::ISeq.expects(:input_to_storage).times(1).returns(storage)
    AOTCompileCache::ISeq.expects(:storage_to_output).times(2).returns(output)
    load(path)
    load(path)
  end

  def test_raises_syntax_error
    path = set_file('a.rb', 'a = (3', 100)
    assert_raises(SyntaxError) do
      # SyntaxError emits directly to stderr in addition to raising, it seems.
      capture_subprocess_io { load(path) }
    end
  end

  def test_no_recache_when_mtime_same
    path = set_file('a.rb', 'a = 3', 100)
    storage = RubyVM::InstructionSequence.compile_file(path).to_binary
    output = RubyVM::InstructionSequence.load_from_binary(storage)
    AOTCompileCache::ISeq.expects(:input_to_storage).times(1).returns(storage)
    AOTCompileCache::ISeq.expects(:storage_to_output).times(2).returns(output)

    load(path)
    set_file(path, 'not the same', 100)
    load(path)
  end

  def test_no_recache_when_mtime_different_but_contents_same
    path = set_file('a.rb', 'a = 3', 100)
    storage = RubyVM::InstructionSequence.compile_file(path).to_binary
    output = RubyVM::InstructionSequence.load_from_binary(storage)
    AOTCompileCache::ISeq.expects(:input_to_storage).times(1).returns(storage)
    AOTCompileCache::ISeq.expects(:storage_to_output).times(2).returns(output)

    load(path)
    set_file(path, 'a = 3', 101)
    load(path)
  end

  def test_recache
    path = set_file('a.rb', 'a = 3', 100)
    storage = RubyVM::InstructionSequence.compile_file(path).to_binary
    output = RubyVM::InstructionSequence.load_from_binary(storage)
    # Totally lies the second time but that's not the point.
    AOTCompileCache::ISeq.expects(:input_to_storage).times(2).returns(storage)
    AOTCompileCache::ISeq.expects(:storage_to_output).times(2).returns(output)

    load(path)
    set_file(path, 'a = 2', 101)
    load(path)
  end

  def test_missing_cache_data
    skip
    path = set_file('a.rb', 'a = 3', 100)
    storage = RubyVM::InstructionSequence.compile_file(path).to_binary
    output = RubyVM::InstructionSequence.load_from_binary(storage)
    # This doesn't really *prove* the file is only read once, but
    # it at least asserts the input is only cached once.
    AOTCompileCache::ISeq.expects(:input_to_storage).times(1).returns(storage)
    AOTCompileCache::ISeq.expects(:storage_to_output).times(2).returns(output)
    load(path)
    `xattr -d com.apple.ResourceFork #{path}`
    load(path)
  end

  private

  def set_file(path, contents, mtime)
    File.write(path, contents)
    FileUtils.touch(path, mtime: mtime)
    path
  end
end
