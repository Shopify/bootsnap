# frozen_string_literal: true
module Bootsnap
  extend(self)

  def bundler?
    return false unless defined?(::Bundler)

    # Bundler environment variable
    %w(BUNDLE_BIN_PATH BUNDLE_GEMFILE).each do |current|
      return true if ENV.key?(current)
    end

    false
  end

  BUNDLE_PATH = if bundler?
    -(Bundler.bundle_path.cleanpath.to_s << '/')
  else
    nil
  end
end
