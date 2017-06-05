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

  spec.summary       = "wip"
  spec.description   = "wip."
  spec.homepage      = "https://github.com/Shopify/bootsnap"

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.extensions    = ['ext/bootsnap/extconf.rb']

  spec.required_ruby_version = '>= 2.3.0'

  spec.add_development_dependency "bundler", '~> 1'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rake-compiler', '~> 0'
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "mocha", "~> 1.2"
  spec.add_development_dependency "ffi-xattr", "~> 0.1.2"

  spec.add_runtime_dependency "msgpack", "~> 1.0"
  spec.add_runtime_dependency "snappy"
end
