# frozen_string_literal: true
source 'https://rubygems.org'

# Specify your gem's dependencies in bootsnap.gemspec
gemspec

if ENV["PSYCH_4"]
  gem "psych", ">= 4"
end

group :development do
  gem 'rubocop'
  gem 'rubocop-shopify', require: false
  gem 'byebug', platform: :ruby
end
