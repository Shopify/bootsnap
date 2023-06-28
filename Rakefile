# frozen_string_literal: true

require("rake/extensiontask")
require("bundler/gem_tasks")

gemspec = Gem::Specification.load("bootsnap.gemspec")
Rake::ExtensionTask.new do |ext|
  ext.name = "bootsnap"
  ext.ext_dir = "ext/bootsnap"
  ext.lib_dir = "lib/bootsnap"
  ext.gem_spec = gemspec
end

require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  # t.test_files = FileList["test/**/*_test.rb"]
  # t.test_files = FileList["test/load_path_cache/*_test.rb"] 
  t.test_files = FileList["test/integration/*_test.rb"] 
end

task(default: %i(compile test))
