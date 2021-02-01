# frozen_string_literal: true

require_relative('bootsnap/version')
require_relative('bootsnap/bundler')
require_relative('bootsnap/load_path_cache')
require_relative('bootsnap/compile_cache')

module Bootsnap
  InvalidConfiguration = Class.new(StandardError)

  def self.setup(
    cache_dir:,
    development_mode: true,
    load_path_cache: true,
    autoload_paths_cache: nil,
    disable_trace: nil,
    compile_cache_iseq: true,
    compile_cache_yaml: true
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

    Bootsnap::LoadPathCache.setup(
      cache_path:       cache_dir + '/bootsnap/load-path-cache',
      development_mode: development_mode,
    ) if load_path_cache

    Bootsnap::CompileCache.setup(
      cache_dir: cache_dir + '/bootsnap/compile-cache',
      iseq: compile_cache_iseq,
      yaml: compile_cache_yaml
    )
  end
end
