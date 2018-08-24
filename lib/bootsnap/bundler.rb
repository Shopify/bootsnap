module Bootsnap
  module_function

  def bundler?
    return false unless defined?(::Bundler)

    # Bundler environment variable
    ['BUNDLE_BIN_PATH', 'BUNDLE_GEMFILE'].each do |current|
      return true if ENV.key?(current)
    end

    false
  end
end
