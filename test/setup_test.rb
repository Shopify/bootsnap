# frozen_string_literal: true

require("test_helper")

module Bootsnap
  class SetupTest < Minitest::Test
    def setup
      @_old_env = ENV.to_h
      @tmp_dir = Dir.mktmpdir("bootsnap-test")
      ENV["BOOTSNAP_CACHE_DIR"] = @tmp_dir
    end

    def teardown
      ENV.replace(@_old_env)
    end

    def test_default_setup
      Bootsnap.expects(:setup).with(
        cache_dir: @tmp_dir,
        development_mode: true,
        load_path_cache: true,
        compile_cache_iseq: Bootsnap.iseq_cache_supported?,
        compile_cache_yaml: true,
        compile_cache_json: true,
      )

      Bootsnap.default_setup
    end

    def test_default_setup_with_ENV_not_dev
      ENV["ENV"] = "something"

      Bootsnap.expects(:setup).with(
        cache_dir: @tmp_dir,
        development_mode: false,
        load_path_cache: true,
        compile_cache_iseq: Bootsnap.iseq_cache_supported?,
        compile_cache_yaml: true,
        compile_cache_json: true,
      )

      Bootsnap.default_setup
    end

    def test_default_setup_with_DISABLE_BOOTSNAP_LOAD_PATH_CACHE
      ENV["DISABLE_BOOTSNAP_LOAD_PATH_CACHE"] = "something"

      Bootsnap.expects(:setup).with(
        cache_dir: @tmp_dir,
        development_mode: true,
        load_path_cache: false,
        compile_cache_iseq: Bootsnap.iseq_cache_supported?,
        compile_cache_yaml: true,
        compile_cache_json: true,
      )

      Bootsnap.default_setup
    end

    def test_default_setup_with_DISABLE_BOOTSNAP_COMPILE_CACHE
      ENV["DISABLE_BOOTSNAP_COMPILE_CACHE"] = "something"

      Bootsnap.expects(:setup).with(
        cache_dir: @tmp_dir,
        development_mode: true,
        load_path_cache: true,
        compile_cache_iseq: false,
        compile_cache_yaml: false,
        compile_cache_json: false,
      )

      Bootsnap.default_setup
    end

    def test_default_setup_with_DISABLE_BOOTSNAP
      ENV["DISABLE_BOOTSNAP"] = "something"

      Bootsnap.expects(:setup).never
      Bootsnap.default_setup
    end

    def test_default_setup_with_BOOTSNAP_LOG
      ENV["BOOTSNAP_LOG"] = "something"

      Bootsnap.expects(:setup).with(
        cache_dir: @tmp_dir,
        development_mode: true,
        load_path_cache: true,
        compile_cache_iseq: Bootsnap.iseq_cache_supported?,
        compile_cache_yaml: true,
        compile_cache_json: true,
      )
      Bootsnap.expects(:logger=).with($stderr.method(:puts))

      Bootsnap.default_setup
    end
  end
end
