# frozen_string_literal: true

require 'test_helper'

module Bootsnap
  module LoadPathCache
    class RealpathCacheTest < MiniTest::Test
      EXTENSIONS = ['', *CACHED_EXTENSIONS]

      def setup
        @cache = RealpathCache.new
        @base_dir = File.realpath(Dir.mktmpdir)
        @absolute_dir = "#{@base_dir}/absolute"
        Dir.mkdir(@absolute_dir)

        @symlinked_dir = "#{@base_dir}/symlink"
        FileUtils.ln_s(@absolute_dir, @symlinked_dir)

        real_caller = File.new("#{@absolute_dir}/real_caller.rb", 'w').path
        symlinked_caller = "#{@absolute_dir}/symlinked_caller.rb"

        FileUtils.ln_s(real_caller, symlinked_caller)

        EXTENSIONS.each do |ext|
          real_required = File.new("#{@absolute_dir}/real_required#{ext}", 'w').path

          symlinked_required = "#{@absolute_dir}/symlinked_required#{ext}"
          FileUtils.ln_s(real_required, symlinked_required)
        end
      end

      def teardown
        FileUtils.remove_entry(@base_dir)
      end

      def remove_required(extensions)
        extensions.each do |ext|
          FileUtils.rm("#{@absolute_dir}/real_required#{ext}")
          FileUtils.rm("#{@absolute_dir}/symlinked_required#{ext}")
        end
      end

      variants = %w(absolute symlink).product(%w(absolute symlink),
        %w(real_caller symlinked_caller),
        %w(real_required symlinked_required))

      variants.each do |caller_dir, required_dir, caller_file, required_file|
        method_name = "test_with_#{caller_dir}_caller_dir_" \
                      "#{required_dir}_require_dir_" \
                      "#{caller_file}_#{required_file}"
        define_method(method_name) do
          caller_path = "#{@base_dir}/#{caller_dir}/#{caller_file}"
          require_path = "../#{required_dir}/#{required_file}.rb"

          expected = "#{@absolute_dir}/real_required.rb"

          assert @cache.call(caller_path, require_path).eql?(expected)
        end

        (EXTENSIONS.size - 1).times do |n|
          removing = EXTENSIONS[0..n]

          define_method("#{method_name}_no#{removing.join('_')}_extensions") do
            caller_path = "#{@base_dir}/#{caller_dir}/#{caller_file}"
            require_path = "../#{required_dir}/#{required_file}"

            remove_required(removing)

            expected = "#{@absolute_dir}/real_required#{EXTENSIONS[n + 1]}"

            assert @cache.call(caller_path, require_path).eql?(expected)
          end
        end

        define_method("#{method_name}_no_files") do
          caller_path = "#{@base_dir}/#{caller_dir}/#{caller_file}"
          require_path = "../#{required_dir}/#{required_file}"

          remove_required(EXTENSIONS)

          expected = "#{@base_dir}/#{required_dir}/#{required_file}"
          assert @cache.call(caller_path, require_path).eql?(expected)
        end
      end
    end
  end
end
