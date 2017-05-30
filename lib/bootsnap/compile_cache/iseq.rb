require 'bootsnap/bootsnap'
require 'zlib'

module Bootsnap
  module CompileCache
    module ISeq
      class << self
        attr_accessor :cache_dir
      end

      def self.input_to_storage(_, path)
        RubyVM::InstructionSequence.compile_file(path).to_binary
      rescue SyntaxError
        raise Uncompilable, 'syntax error'
      rescue RuntimeError => e
        if e.message == 'should not compile with coverage'
          raise Uncompilable, 'coverage is enabled'
        else
          raise
        end
      end

      def self.storage_to_output(binary)
        RubyVM::InstructionSequence.load_from_binary(binary)
      rescue RuntimeError => e
        if e.message == 'broken binary format'
          STDERR.puts "[Bootsnap::CompileCache] warning: rejecting broken binary"
          return nil
        else
          raise
        end
      end

      def self.input_to_output(_)
        nil # ruby handles this
      end

      module InstructionSequenceMixin
        def load_iseq(path)
          Bootsnap::CompileCache::Native.fetch(
            Bootsnap::CompileCache::ISeq.cache_dir,
            path.to_s,
            Bootsnap::CompileCache::ISeq
          )
        rescue RuntimeError => e
          if e.message =~ /unmatched platform/
            puts "unmatched platform for file #{path}"
          end
          raise
        rescue Errno::ERANGE
          STDERR.puts <<~EOF
            \x1b[31mError loading ISeq from cache for \x1b[1;34m#{path}\x1b[0;31m!
            You can likely fix this by running:
              \x1b[1;32mxattr -c #{path}
            \x1b[0;31m...but, first, please make sure \x1b[1;34m@burke\x1b[0;31m knows you ran into this bug!
            He will want to see the results of:
              \x1b[1;32m/bin/ls -l@ #{path}
            \x1b[0;31mand:
              \x1b[1;32mxattr -p user.aotcc.key #{path}\x1b[0m
          EOF
          raise
        end

        def compile_option=(hash)
          super(hash)
          Bootsnap::CompileCache::ISeq.compile_option_updated
        end
      end

      def self.compile_option_updated
        option = RubyVM::InstructionSequence.compile_option
        crc = Zlib.crc32(option.inspect)
        Bootsnap::CompileCache::Native.compile_option_crc32 = crc
      end

      def self.install!(cache_dir)
        Bootsnap::CompileCache::ISeq.cache_dir = cache_dir
        Bootsnap::CompileCache::ISeq.compile_option_updated
        class << RubyVM::InstructionSequence
          prepend InstructionSequenceMixin
        end
      end
    end
  end
end

