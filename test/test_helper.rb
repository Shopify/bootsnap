$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'bundler/setup'
require 'bootsnap'

require 'minitest/autorun'
require 'mocha/mini_test'

module NullCache
  def self.get(*)
  end

  def self.set(*)
  end

  def self.fetch(*)
    yield
  end
end
