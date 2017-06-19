$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'bundler/setup'
require 'bootsnap'

require 'tmpdir'
require 'fileutils'

require 'minitest/autorun'
require 'mocha/mini_test'

cache_dir = File.expand_path('../../tmp/bootsnap-compile-cache', __FILE__)
Bootsnap::CompileCache.setup(cache_dir: cache_dir, iseq: true, yaml: false)

module TestHandler
  def self.input_to_storage(i, p)
    'neato ' + p
  end

  def self.storage_to_output(d)
    d.upcase
  end

  def self.input_to_output(d)
    raise 'but why tho'
  end
end

module NullCache
  def self.get(*)
  end

  def self.set(*)
  end

  def self.transaction(*)
    yield
  end

  def self.fetch(*)
    yield
  end
end

module MiniTest::Test::Help
  class << self
    def binary(str)
      str.force_encoding(Encoding::BINARY)
    end

    def cache_path(dir, file)
      hex = fnv1a_64(file).to_s(16)
      "#{dir}/#{hex[0..1]}/#{hex[2..-1]}"
    end

    def fnv1a_64(data)
      hash = 0xcbf29ce484222325
      data.bytes.each do |byte|
        hash = hash ^ byte
        hash = (hash * 0x100000001b3) % (2 ** 64)
      end
      hash
    end

    def set_file(path, contents, mtime)
      File.write(path, contents)
      FileUtils.touch(path, mtime: mtime)
      path
    end
  end
end

module TmpdirHelper
  def setup
    super
    @prev_dir = Dir.pwd
    @tmp_dir = Dir.mktmpdir('bootsnap-test')
    Dir.chdir(@tmp_dir)
    @prev = Bootsnap::CompileCache::ISeq.cache_dir
    Bootsnap::CompileCache::ISeq.cache_dir = @tmp_dir
  end

  def teardown
    super
    Dir.chdir(@prev_dir)
    FileUtils.remove_entry(@tmp_dir)
    Bootsnap::CompileCache::ISeq.cache_dir = @prev
  end
end
