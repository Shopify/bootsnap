require 'bootsnap/version'
require 'bootsnap/bootsnap' # BootSnap::Native

class BootSnap
  InvalidConfiguration = Class.new(StandardError)

  def self.setup(cache_dir:, development_mode:, iseq: true, yaml: true, require: true, as_autoload: true)
    if as_autoload && !require
      raise InvalidConfiguration, "feature 'as_autoload' depends on feature 'require'"
    end

    setup_iseq                                 if iseq
    setup_yaml                                 if yaml
    setup_require(cache_dir, development_mode) if require
    setup_as_autoload(development_mode)        if as_autoload
  end

  def self.setup_iseq
    require 'bootsnap/iseq'
    BootSnap::ISeq.setup
  end

  def self.setup_yaml
    require 'bootsnap/yaml'
    BootSnap::YAML.setup
  end

  def self.setup_require(cache_dir, devmode)
    require 'bootscale'
    Bootscale.setup(cache_directory: cache_dir, development_mode: devmode)
  end

  def self.setup_as_autoload(devmode)
    require 'bootscale/active_support'
    Bootscale::ActiveSupport.setup(development_mode: devmode)
  end
end
