require_relative 'bootsnap/version'
require_relative 'bootsnap/bootsnap' # BootSnap::Native

class BootSnap
  InvalidConfiguration = Class.new(StandardError)

  def self.setup(cache_dir:, development_mode:, iseq: true, yaml: true, require: true, as_autoload: true)
    if as_autoload && !require
      raise InvalidConfiguration, "feature 'as_autoload' depends on feature 'require'"
    end

    setup_iseq                                 if iseq
    setup_require(cache_dir, development_mode) if require
    setup_as_autoload(development_mode)        if as_autoload
    setup_yaml                                 if yaml
  end

  def self.setup_iseq
    require_relative 'bootsnap/iseq'
    BootSnap::ISeq.setup
  end

  def self.setup_yaml
    require_relative 'bootsnap/yaml'
    BootSnap::YAML.setup
  end

  def self.setup_require(cache_dir, devmode)
    require_relative 'bs2'
    # Bootscale.setup(cache_directory: cache_dir, development_mode: devmode)
    BS2.setup(return_false: [], guarantee_fail: [])
  end

  def self.setup_as_autoload(devmode)
    require_relative 'bs2_as'
    # Bootscale::ActiveSupport.setup(development_mode: devmode)
    BS2AS.setup
  end
end
