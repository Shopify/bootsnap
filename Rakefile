require 'rake/extensiontask'

gemspec = Gem::Specification.load('aot_compile_cache.gemspec')
Rake::ExtensionTask.new do |ext|
  ext.name = 'aot_compile_cache'
  ext.ext_dir = 'ext/aot_compile_cache'
  ext.lib_dir = 'lib/aot_compile_cache'
  ext.gem_spec = gemspec
end

task(default: :compile)
