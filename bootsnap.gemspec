# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'bootsnap/version'

Gem::Specification.new do |spec|
  spec.name          = "bootsnap"
  spec.version       = BootSnap::VERSION
  spec.authors       = ["Burke Libbey"]
  spec.email         = ["burke@libbey.me"]

  spec.summary       = "wip"
  spec.description   = "wip."
  spec.homepage      = "https://github.com/Shopify/bootsnap"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.extensions    = ["ext/bootsnap/extconf.rb"]

  spec.add_development_dependency "bundler", "~> 1.14.a"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rake-compiler"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "mocha", "~> 1.2"

  spec.add_runtime_dependency "msgpack", ">= 1.0.2"
  spec.add_runtime_dependency "bootscale", "0.7.0"
end
