# frozen_string_literal: true

require 'bootsnap'
require 'optparse'
require 'fileutils'

module Bootsnap
  class CLI
    unless Regexp.method_defined?(:match?)
      module RegexpMatchBackport
        refine Regexp do
          def match?(string)
            !!match(string)
          end
        end
      end
      using RegexpMatchBackport
    end

    attr_reader :cache_dir, :argv

    attr_accessor :compile_gemfile, :exclude

    def initialize(argv)
      @argv = argv
      self.cache_dir = ENV.fetch('BOOTSNAP_CACHE_DIR', 'tmp/cache')
      self.compile_gemfile = false
      self.exclude = nil
    end

    def precompile_command(*sources)
      require 'bootsnap/compile_cache/iseq'

      fix_default_encoding do
        Bootsnap::CompileCache::ISeq.cache_dir = self.cache_dir

        if compile_gemfile
          sources += $LOAD_PATH
        end

        sources.map { |d| File.expand_path(d) }.each do |path|
          if !exclude || !exclude.match?(path)
            list_ruby_files(path).each do |ruby_file|
              if !exclude || !exclude.match?(ruby_file)
                CompileCache::ISeq.fetch(ruby_file, cache_dir: cache_dir)
              end
            end
          end
        end
      end
      0
    end

    dir_sort = begin
      Dir['.', sort: false]
      true
    rescue ArgumentError, TypeError
      false
    end

    if dir_sort
      def list_ruby_files(path)
        if File.directory?(path)
          Dir[File.join(path, '**/*.rb'), sort: false]
        elsif File.exist?(path)
          [path]
        else
          []
        end
      end
    else
      def list_ruby_files(path)
        if File.directory?(path)
          Dir[File.join(path, '**/*.rb')]
        elsif File.exist?(path)
          [path]
        else
          []
        end
      end
    end

    def run
      parser.parse!(argv)
      command = argv.shift
      method = "#{command}_command"
      if respond_to?(method)
        public_send(method, *argv)
      else
        invalid_usage!("Unknown command: #{command}")
      end
    end

    private

    def fix_default_encoding
      if Encoding.default_external == Encoding::US_ASCII
        Encoding.default_external = Encoding::UTF_8
        begin
          yield
        ensure
          Encoding.default_external = Encoding::US_ASCII
        end
      else
        yield
      end
    end

    def invalid_usage!(message)
      STDERR.puts message
      STDERR.puts
      STDERR.puts parser
      1
    end

    def cache_dir=(dir)
      @cache_dir = File.expand_path(File.join(dir, 'bootsnap-compile-cache'))
    end

    def parser
      @parser ||= OptionParser.new do |opts|
        opts.banner = "Usage: bootsnap COMMAND [ARGS]"
        opts.separator ""
        opts.separator "GLOBAL OPTIONS"
        opts.separator ""

        help = <<~EOS
          Path to the bootsnap cache directory. Defaults to tmp/cache
        EOS
        opts.on('--cache-dir DIR', help.strip) do |dir|
          self.cache_dir = dir
        end

        opts.separator ""
        opts.separator "COMMANDS"
        opts.separator ""
        opts.separator "    precompile [DIRECTORIES...]: Precompile all .rb files in the passed directories"

        help = <<~EOS
          Precompile the gems in Gemfile
        EOS
        opts.on('--gemfile', help) { self.compile_gemfile = true }

        help = <<~EOS
          Path pattern to not precompile. e.g. --exclude 'aws-sdk|google-api'
        EOS
        opts.on('--exclude PATTERN', help) { |pattern| self.exclude = Regexp.new(pattern) }
      end
    end
  end
end
