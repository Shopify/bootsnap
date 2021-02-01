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
    disable_trace: false,
    compile_cache_iseq: true,
    compile_cache_yaml: true
  )
    unless autoload_paths_cache.nil?
      warn "[DEPRECATED] Bootsnap's `autoload_paths_cache:` option is deprecated and will be removed. " \
        "If you use Zeitwerk this option is useless, and if you are still using the classic autoloader " \
        "upgrading is recommended."
    end
    setup_disable_trace if disable_trace

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

  def self.setup_disable_trace
    if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('2.5.0')
      warn(
        "from #{caller_locations(1, 1)[0]}: The 'disable_trace' method is not allowed with this Ruby version. " \
        "current: #{RUBY_VERSION}, allowed version: < 2.5.0",
      )
    else
      RubyVM::InstructionSequence.compile_option = { trace_instruction: false }
    end
  end
end
