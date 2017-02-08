require_relative 'bootsnap/version'
require_relative 'bootsnap/bootsnap' # Bootsnap::Native

module Bootsnap
  InvalidConfiguration = Class.new(StandardError)

  def self.setup(
    cache_dir:, development_mode: true,
    aot_ruby: true, aot_yaml: true, load_path_prescan: true, autoload_path_prescan: true, disable_trace: false,
    guarantee_load_fail: [], return_false: []
  )
    if autoload_path_prescan && !load_path_prescan
      raise InvalidConfiguration, "feature 'as_autoload' depends on feature 'require'"
    end

    cd = cache_dir
    gf = guarantee_load_fail
    rf = return_false

    setup_disable_trace                 if disable_trace
    setup_aot_ruby                      if aot_ruby
    setup_load_path_prescan(cd, gf, rf) if load_path_prescan
    setup_autoload_path_prescan(cd)     if autoload_path_prescan
    setup_aot_yaml                      if aot_yaml
  end

  def self.setup_disable_trace
    RubyVM::InstructionSequence.compile_option = { trace_instruction: false }
  end

  def self.setup_aot_ruby
    require_relative 'bootsnap/iseq'
    Bootsnap::ISeq.setup
  end

  def self.setup_aot_yaml
    require_relative 'bootsnap/yaml'
    Bootsnap::YAML.setup
  end

  # TODO: configuration:
  # * cache_dir
  # * devlopment mode?
  def self.setup_load_path_prescan(cd, gf, rf)
    require_relative 'bootsnap/load_path_cache'
    dbfile = File.join(cd, 'bootsnap-path-cache')
    LoadPathCache.load_path_cache = LoadPathCache::Cache.new(dbfile, gf, rf)
    require_relative 'bootsnap/load_path_cache/core_ext'
  end

  def self.setup_autoload_path_prescan(cd)
    require_relative 'bootsnap/load_path_cache'
    dbfile = File.join(cd, 'bootsnap-path-cache')
    LoadPathCache.autoload_path_cache = LoadPathCache::Cache.new(dbfile)
    require_relative 'bootsnap/load_path_cache/active_support/core_ext'
  end
end
