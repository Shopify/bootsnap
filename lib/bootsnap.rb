require 'bootsnap/version'
require 'bootsnap/bootsnap' # BootSnap::Native

class BootSnap
  def self.setup(iseq: true, yaml: true)
    setup_iseq if iseq
    setup_yaml if yaml
  end

  def self.setup_iseq
    require 'bootsnap/iseq'
    BootSnap::ISeq.setup
  end

  def self.setup_yaml
    require 'bootsnap/yaml'
    BootSnap::YAML.setup
  end
end
