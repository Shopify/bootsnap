require 'test_helper'
require 'bootsnap/dirscanner'

class DirScannerTest < Minitest::Test
  DIRECTORIES = %w[node_modules tmp/cache tmp/important app lib].freeze
  FILES = %w[
    test test.rb tmp/cache/file.rb tmp/cache/.gitignore tmp/cache/test
    tmp/important/file.rb tmp/file.rb node_modules/leftpad.js node_modules/right_pad
    lib/file.rb lib/.gitignore app/config.rb tmp.rb
  ].freeze

  def with_directory_struture
    Dir.mktmpdir do |dir|
      DIRECTORIES.each do |dr|
        FileUtils.mkdir_p(File.join(dir, dr))
      end
      FILES.each do |file|
        FileUtils.touch(File.join(dir, file))
      end

      yield(dir)
    end
  end

  def test_with_no_exclusions
    with_directory_struture do |dir|
      detected = []
      Bootsnap::DirScanner.scan(dir, excluded: []) do |path|
        detected << path
      end

      expected = (DIRECTORIES + FILES + ['tmp'])
        .reject { |f| File.basename(f)[0] == '.' }
        .sort
        .map { |f| File.join(dir, f) }
      
      assert_equal(detected.sort, expected)
    end
  end

  def test_without_second_argument
    with_directory_struture do |dir|
      detected = []
      Bootsnap::DirScanner.scan(dir) do |path|
        detected << path
      end

      expected = (DIRECTORIES + FILES + ['tmp'])
        .reject { |f| File.basename(f)[0] == '.' }
        .sort
        .map { |f| File.join(dir, f) }
      
      assert_equal(detected.sort, expected)
    end
  end

  def test_with_exclusions
    with_directory_struture do |dir|
      excluded = %w[node_modules tmp/cache].map { |f| File.join(dir, f) }
      detected = []
      Bootsnap::DirScanner.scan(dir, excluded: excluded) do |path|
        detected << path
      end

      expected = %w[
        tmp tmp/file.rb tmp/important tmp/important/file.rb  tmp.rb
        app app/config.rb lib lib/file.rb
        test test.rb
      ].sort.map { |f| File.join(dir, f) }

      assert_equal(detected.sort, expected)
    end
  end
end