require 'rake/extensiontask'

gemspec = Gem::Specification.load('bootsnap.gemspec')
Rake::ExtensionTask.new do |ext|
  ext.name = 'bootsnap'
  ext.ext_dir = 'ext/bootsnap'
  ext.lib_dir = 'lib/bootsnap'
  ext.gem_spec = gemspec
end

task(default: :compile)
