# frozen_string_literal: true
$LOAD_PATH.unshift(File.expand_path('../../lib', __FILE__))

if defined? Warning
  if Warning.respond_to?(:[]=)
    Warning[:deprecated] = true
  end
end

require('bundler/setup')
require('bootsnap')
require('bootsnap/compile_cache/yaml')

require('tmpdir')
require('fileutils')

require('minitest/autorun')
require('mocha/minitest')

cache_dir = File.expand_path('../../tmp/bootsnap/compile-cache', __FILE__)
Bootsnap::CompileCache.setup(cache_dir: cache_dir, iseq: true, yaml: false)

if GC.respond_to?(:verify_compaction_references)
  # This method was added in Ruby 3.0.0. Calling it this way asks the GC to
  # move objects around, helping to find object movement bugs.
  GC.verify_compaction_references(double_heap: true, toward: :empty)
end

module TestHandler
  def self.input_to_storage(_i, p)
    'neato ' + p
  end

  def self.storage_to_output(d, _a)
    d.upcase
  end

  def self.input_to_output(_d, _a)
    raise('but why tho')
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

module MiniTest
  class Test
    module Help
      class << self
        def binary(str)
          str.force_encoding(Encoding::BINARY)
        end

        def cache_path(dir, file, args_key = nil)
          hash = fnv1a_64(file)
          unless args_key.nil?
            hash ^= fnv1a_64(args_key)
          end

          hex = hash.to_s(16)
          "#{dir}/#{hex[0..1]}/#{hex[2..-1]}"
        end

        def fnv1a_64(data)
          hash = 0xcbf29ce484222325
          data.bytes.each do |byte|
            hash = hash ^ byte
            hash = (hash * 0x100000001b3) % (2**64)
          end
          hash
        end

        def set_file(path, contents, mtime)
          FileUtils.mkdir_p(File.dirname(path))
          File.write(path, contents)
          FileUtils.touch(path, mtime: mtime)
          path
        end
      end
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
    Bootsnap::CompileCache::YAML.cache_dir = @tmp_dir
  end

  def teardown
    super
    Dir.chdir(@prev_dir)
    FileUtils.remove_entry(@tmp_dir)
    Bootsnap::CompileCache::ISeq.cache_dir = @prev
    Bootsnap::CompileCache::YAML.cache_dir = @prev
  end
end
