require_relative 'bootsnap/version'
require_relative 'bootsnap/bootsnap' # Bootsnap::Native

class Bootsnap
  InvalidConfiguration = Class.new(StandardError)

  def self.setup(
    cache_dir:, development_mode:,
    aot_ruby: true, aot_yaml: true, load_path_prescan: true, autoload_path_prescan: true, disable_trace: false,
    guarantee_load_fail: []
  )
    if autoload_path_prescan && !load_path_prescan
      raise InvalidConfiguration, "feature 'as_autoload' depends on feature 'require'"
    end

    gf = guarantee_load_fail

    setup_disable_trace         if disable_trace
    setup_aot_ruby              if aot_ruby
    setup_load_path_prescan(gf) if load_path_prescan
    setup_autoload_path_prescan if autoload_path_prescan
    setup_aot_yaml              if aot_yaml
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

  def self.setup_load_path_prescan(gf)
    require_relative 'bs2'
    # Bootscale.setup(cache_directory: cache_dir, development_mode: devmode)
    BS2.setup(return_false: [], guarantee_fail: gf)
  end

  def self.setup_autoload_path_prescan
    require_relative 'bs2_as'
    # Bootscale::ActiveSupport.setup(development_mode: devmode)
    BS2AS.setup
  end
end
