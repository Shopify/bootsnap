# frozen_string_literal: true
require('rake/extensiontask')
require('bundler/gem_tasks')

gemspec = Gem::Specification.load('bootsnap.gemspec')
Rake::ExtensionTask.new do |ext|
  ext.name = 'bootsnap'
  ext.ext_dir = 'ext/bootsnap'
  ext.lib_dir = 'lib/bootsnap'
  ext.gem_spec = gemspec
end

task :test do
  sh 'bin/testunit'
end

task(default: %i(compile test))
