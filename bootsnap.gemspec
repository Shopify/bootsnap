# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'bootsnap/version'

Gem::Specification.new do |spec|
  spec.name          = "bootsnap"
  spec.version       = Bootsnap::VERSION
  spec.authors       = ["Burke Libbey"]
  spec.email         = ["burke.libbey@shopify.com"]

  spec.license       = "MIT"

  spec.summary       = "Boot large ruby/rails apps faster"
  spec.description   = spec.summary
  spec.homepage      = "https://github.com/Shopify/bootsnap"

  spec.files         = Dir['{lib/**/*,[A-Z]*}']
  spec.require_path  = 'lib'

  spec.required_ruby_version = '>= 2.0.0'

  spec.add_dependency 'helix_runtime', '~> 0.6.0'

  spec.add_development_dependency "bundler", '~> 1'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rake-compiler', '~> 0'
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "mocha", "~> 1.2"

  spec.add_runtime_dependency "msgpack", "~> 1.0"
end
