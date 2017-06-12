require_relative 'bootsnap/version'
require_relative 'bootsnap/load_path_cache'
require_relative 'bootsnap/compile_cache'
require_relative 'bootsnap/cache_wrapper'
require_relative 'bootsnap/load_path_cache/store'

module Bootsnap
  InvalidConfiguration = Class.new(StandardError)

  def self.setup(
    cache_dir:,
    development_mode: true,
    load_path_cache: true,
    autoload_paths_cache: true,
    disable_trace: false,
    compile_cache_iseq: true,
    compile_cache_yaml: true
  )
    load_path_cache &&= CacheWrapper.get(load_path_cache) ||
      Bootsnap::LoadPathCache::Store.new(cache_dir + '/bootsnap-load-path-cache')

    default_compile_cache = CacheWrapper.get(
      Bootsnap::LoadPathCache::Store.new(cache_dir + '/bootsnap-compile-cache')
    )

    compile_cache_iseq &&= CacheWrapper.get(compile_cache_iseq) || default_compile_cache
    compile_cache_yaml &&= CacheWrapper.get(compile_cache_yaml) || default_compile_cache

    if autoload_paths_cache && !load_path_cache
      raise InvalidConfiguration, "feature 'autoload_paths_cache' depends on feature 'load_path_cache'"
    end

    setup_disable_trace if disable_trace

    Bootsnap::LoadPathCache.setup(
      cache:            load_path_cache,
      development_mode: development_mode,
      active_support:   autoload_paths_cache
    ) if load_path_cache

    Bootsnap::CompileCache.setup(
      iseq: compile_cache_iseq,
      yaml: compile_cache_yaml
    )
  end

  def self.setup_disable_trace
    RubyVM::InstructionSequence.compile_option = { trace_instruction: false }
  end
end
