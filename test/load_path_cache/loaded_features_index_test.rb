# frozen_string_literal: true

require("test_helper")

module Bootsnap
  module LoadPathCache
    class LoadedFeaturesIndexTest < MiniTest::Test
      def setup
        @index = LoadedFeaturesIndex.new
        # not really necessary but let's just make it a clean slate
        @index.instance_variable_set(:@lfi, {})
      end

      def test_successful_addition
        refute(@index.key?("bundler"))
        refute(@index.key?("bundler.rb"))
        refute(@index.key?("foo"))
        @index.register("bundler", "/a/b/bundler.rb")
        assert(@index.key?("bundler"))
        assert(@index.key?("bundler.rb"))
        refute(@index.key?("foo"))
      end

      def test_infer_base_from_ext
        refute(@index.key?("bundler"))
        refute(@index.key?("bundler.rb"))
        refute(@index.key?("foo"))
        @index.register("bundler.rb", nil)
        assert(@index.key?("bundler"))
        assert(@index.key?("bundler.rb"))
        refute(@index.key?("foo"))
      end

      def test_only_strip_elidable_ext
        # It is only valid to strip a '.rb' or shared library extension from the
        # end of a filename, not anything else.
        #
        # E.g. 'descriptor.pb.rb' if required via 'descriptor.pb'
        # should never be shortened to merely 'descriptor'!
        refute(@index.key?("descriptor.pb"))
        refute(@index.key?("descriptor.pb.rb"))
        refute(@index.key?("descriptor.rb"))
        refute(@index.key?("descriptor"))
        refute(@index.key?("foo"))
        @index.register("descriptor.pb.rb", nil)
        assert(@index.key?("descriptor.pb"))
        assert(@index.key?("descriptor.pb.rb"))
        refute(@index.key?("descriptor.rb"))
        refute(@index.key?("descriptor"))
        refute(@index.key?("foo"))
      end

      def test_shared_library_ext_considered_elidable
        # Check that '.dylib' (token shared library extension) is treated as elidable,
        # and doesn't get mixed up with Ruby '.rb' files.
        refute(@index.key?("libgit2.dylib"))
        refute(@index.key?("libgit2.dylib.rb"))
        refute(@index.key?("descriptor.rb"))
        refute(@index.key?("descriptor"))
        refute(@index.key?("foo"))
        @index.register("libgit2.dylib", nil)
        assert(@index.key?("libgit2.dylib"))
        refute(@index.key?("libgit2.dylib.rb"))
        refute(@index.key?("libgit2.rb"))
        refute(@index.key?("foo"))
      end

      def test_cannot_infer_ext_from_base # Current limitation
        refute(@index.key?("bundler"))
        refute(@index.key?("bundler.rb"))
        refute(@index.key?("foo"))
        @index.register("bundler", nil)
        assert(@index.key?("bundler"))
        refute(@index.key?("bundler.rb"))
        refute(@index.key?("foo"))
      end

      def test_purge_loaded_feature
        refute(@index.key?("bundler"))
        refute(@index.key?("bundler.rb"))
        refute(@index.key?("foo"))
        @index.register("bundler", "/a/b/bundler.rb")
        assert(@index.key?("bundler"))
        assert(@index.key?("bundler.rb"))
        refute(@index.key?("foo"))
        @index.purge("/a/b/bundler.rb")
        refute(@index.key?("bundler"))
        refute(@index.key?("bundler.rb"))
        refute(@index.key?("foo"))
      end

      def test_purge_multi_loaded_feature
        refute(@index.key?("bundler"))
        refute(@index.key?("bundler.rb"))
        refute(@index.key?("foo"))
        @index.register("bundler", "/a/b/bundler.rb")
        assert(@index.key?("bundler"))
        assert(@index.key?("bundler.rb"))
        refute(@index.key?("foo"))
        @index.purge_multi(["/a/b/bundler.rb", "/a/b/does-not-exist.rb"])
        refute(@index.key?("bundler"))
        refute(@index.key?("bundler.rb"))
        refute(@index.key?("foo"))
      end

      def test_register_finds_correct_feature
        refute(@index.key?("bundler"))
        refute(@index.key?("bundler.rb"))
        refute(@index.key?("foo"))
        cursor = @index.cursor("bundler")
        $LOADED_FEATURES << "/a/b/bundler.rb"
        long = @index.identify("bundler", cursor)
        @index.register("bundler", long)
        assert(@index.key?("bundler"))
        assert(@index.key?("bundler.rb"))
        refute(@index.key?("foo"))
        @index.purge("/a/b/bundler.rb")
        refute(@index.key?("bundler"))
        refute(@index.key?("bundler.rb"))
        refute(@index.key?("foo"))
      end

      def test_derives_initial_state_from_loaded_features
        index = LoadedFeaturesIndex.new
        assert(index.key?("minitest/autorun"))
        assert(index.key?("minitest/autorun.rb"))
        refute(index.key?("minitest/autorun.so"))
      end

      def test_ignores_absolute_paths
        path = "#{Dir.mktmpdir}/bundler.rb"
        assert_nil @index.cursor(path)
        @index.register(path, path)
        refute(@index.key?(path))
      end
    end
  end
end
