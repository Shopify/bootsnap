# coding: utf-8
# frozen_string_literal: true
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require('bootsnap/version')

Gem::Specification.new do |spec|
  spec.name          = "bootsnap"
  spec.version       = Bootsnap::VERSION
  spec.authors       = ["Burke Libbey"]
  spec.email         = ["burke.libbey@shopify.com"]

  spec.license       = "MIT"

  spec.summary       = "Boot large ruby/rails apps faster"
  spec.description   = spec.summary
  spec.homepage      = "https://github.com/Shopify/bootsnap"

  spec.metadata = {
    'bug_tracker_uri' => 'https://github.com/Shopify/bootsnap/issues',
    'changelog_uri' => 'https://github.com/Shopify/bootsnap/blob/master/CHANGELOG.md',
    'source_code_uri' => 'https://github.com/Shopify/bootsnap',
    'allowed_push_host' => 'https://rubygems.org'
  }

  spec.files = %x(git ls-files -z ext lib).split("\x0") + %w(CHANGELOG.md LICENSE.txt README.md)
  spec.require_paths = %w(lib)

  spec.bindir        = 'exe'
  spec.executables   = %w(bootsnap)

  spec.required_ruby_version = '>= 2.3.0'

  if RUBY_PLATFORM =~ /java/
    spec.platform = 'java'
  else
    spec.platform    = Gem::Platform::RUBY
    spec.extensions  = ['ext/bootsnap/extconf.rb']
  end

  spec.add_development_dependency("bundler")
  spec.add_development_dependency('rake')
  spec.add_development_dependency('rake-compiler')
  spec.add_development_dependency("minitest", "~> 5.0")
  spec.add_development_dependency("mocha", "~> 1.2")

  spec.add_runtime_dependency("msgpack", "~> 1.4")
end
