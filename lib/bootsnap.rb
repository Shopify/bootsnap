# frozen_string_literal: true

require_relative("bootsnap/version")
require_relative("bootsnap/bundler")
require_relative("bootsnap/load_path_cache")
require_relative("bootsnap/compile_cache")

module Bootsnap
  InvalidConfiguration = Class.new(StandardError)

  class << self
    attr_reader :logger

    def log!
      self.logger = $stderr.method(:puts)
    end

    def logger=(logger)
      @logger = logger
      self.instrumentation = if logger.respond_to?(:debug)
        ->(event, path) { @logger.debug("[Bootsnap] #{event} #{path}") }
      else
        ->(event, path) { @logger.call("[Bootsnap] #{event} #{path}") }
      end
    end

    def instrumentation=(callback)
      @instrumentation = callback
      if respond_to?(:instrumentation_enabled=, true)
        self.instrumentation_enabled = !!callback
      end
    end

    def _instrument(event, path)
      @instrumentation.call(event, path)
    end

    def setup(
      cache_dir:,
      development_mode: true,
      load_path_cache: true,
      autoload_paths_cache: nil,
      disable_trace: nil,
      compile_cache_iseq: true,
      compile_cache_yaml: true,
      compile_cache_json: true
    )
      unless autoload_paths_cache.nil?
        warn "[DEPRECATED] Bootsnap's `autoload_paths_cache:` option is deprecated and will be removed. " \
          "If you use Zeitwerk this option is useless, and if you are still using the classic autoloader " \
          "upgrading is recommended."
      end

      unless disable_trace.nil?
        warn "[DEPRECATED] Bootsnap's `disable_trace:` option is deprecated and will be removed. " \
          "If you use Ruby 2.5 or newer this option is useless, if not upgrading is recommended."
      end

      if compile_cache_iseq && !iseq_cache_supported?
        warn "Ruby 2.5 has a bug that break code tracing when code is loaded from cache. It is recommened " \
          "to turn `compile_cache_iseq` off on Ruby 2.5"
      end

      if load_path_cache
        Bootsnap::LoadPathCache.setup(
          cache_path: cache_dir + "/bootsnap/load-path-cache",
          development_mode: development_mode,
        )
      end

      Bootsnap::CompileCache.setup(
        cache_dir: cache_dir + "/bootsnap/compile-cache",
        iseq: compile_cache_iseq,
        yaml: compile_cache_yaml,
        json: compile_cache_json,
      )
    end

    def iseq_cache_supported?
      return @iseq_cache_supported if defined? @iseq_cache_supported

      ruby_version = Gem::Version.new(RUBY_VERSION)
      @iseq_cache_supported = ruby_version < Gem::Version.new("2.5.0") || ruby_version >= Gem::Version.new("2.6.0")
    end

    def default_setup
      env = ENV["RAILS_ENV"] || ENV["RACK_ENV"] || ENV["ENV"]
      development_mode = ["", nil, "development"].include?(env)

      unless ENV["DISABLE_BOOTSNAP"]
        cache_dir = ENV["BOOTSNAP_CACHE_DIR"]
        unless cache_dir
          config_dir_frame = caller.detect do |line|
            line.include?("/config/")
          end

          unless config_dir_frame
            $stderr.puts("[bootsnap/setup] couldn't infer cache directory! Either:")
            $stderr.puts("[bootsnap/setup]   1. require bootsnap/setup from your application's config directory; or")
            $stderr.puts("[bootsnap/setup]   2. Define the environment variable BOOTSNAP_CACHE_DIR")

            raise("couldn't infer bootsnap cache directory")
          end

          path = config_dir_frame.split(/:\d+:/).first
          path = File.dirname(path) until File.basename(path) == "config"
          app_root = File.dirname(path)

          cache_dir = File.join(app_root, "tmp", "cache")
        end

        setup(
          cache_dir: cache_dir,
          development_mode: development_mode,
          load_path_cache: !ENV["DISABLE_BOOTSNAP_LOAD_PATH_CACHE"],
          compile_cache_iseq: !ENV["DISABLE_BOOTSNAP_COMPILE_CACHE"] && iseq_cache_supported?,
          compile_cache_yaml: !ENV["DISABLE_BOOTSNAP_COMPILE_CACHE"],
          compile_cache_json: !ENV["DISABLE_BOOTSNAP_COMPILE_CACHE"],
        )

        if ENV["BOOTSNAP_LOG"]
          log!
        end
      end
    end

    if RbConfig::CONFIG["host_os"] =~ /mswin|mingw|cygwin/
      def absolute_path?(path)
        path[1] == ":"
      end
    else
      def absolute_path?(path)
        path.start_with?("/")
      end
    end

    # This is a semi-accurate ruby implementation of the native `rb_get_path(VALUE)` function.
    # The native version is very intricate and may behave differently on windows etc.
    # But we only use it for non-MRI platform.
    def rb_get_path(fname)
      path_path = fname.respond_to?(:to_path) ? fname.to_path : fname
      String.try_convert(path_path) || raise(TypeError, "no implicit conversion of #{path_path.class} into String")
    end

    # Allow the C extension to redefine `rb_get_path` without warning.
    alias_method :rb_get_path, :rb_get_path # rubocop:disable Lint/DuplicateMethods
  end
end
