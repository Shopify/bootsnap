# frozen_string_literal: true

module Bootsnap
  class CLI
    class WorkerPool
      class << self
        def create(size:, jobs:)
          if size > 0 && Process.respond_to?(:fork)
            new(size: size, jobs: jobs)
          else
            Inline.new(jobs: jobs)
          end
        end
      end

      class Inline
        def initialize(jobs: {})
          @jobs = jobs
        end

        def push(job, *args)
          @jobs.fetch(job).call(*args)
          nil
        end

        def spawn
          # noop
        end

        def shutdown
          # noop
        end
      end

      class Worker
        attr_reader :to_io, :pid

        def initialize(jobs)
          @jobs = jobs
          @pipe_out, @to_io = IO.pipe(binmode: true)
          # Set the writer encoding to binary since IO.pipe only sets it for the reader.
          # https://github.com/rails/rails/issues/16514#issuecomment-52313290
          @to_io.set_encoding(Encoding::BINARY)

          @pid = nil
        end

        def write(message)
          payload = Marshal.dump(message)
          to_io.write_nonblock(payload)
        end

        def close
          to_io.close
        end

        def work_loop
          loop do
            job, *args = Marshal.load(@pipe_out)
            return if job == :exit

            @jobs.fetch(job).call(*args)
          end
        rescue IOError
          nil
        end

        def spawn
          @pid = Process.fork do
            to_io.close
            work_loop
            exit!(true)
          end
          @pipe_out.close
          true
        end
      end

      def initialize(size:, jobs: {})
        @size = size
        @jobs = jobs
        @queue = Thread::Queue.new
        @pids = []
      end

      def spawn
        @workers = @size.times.map { Worker.new(@jobs) }
        @workers.each(&:spawn)
        @dispatcher_thread = Thread.new { dispatch_loop }
        @dispatcher_thread.abort_on_exception = true
        true
      end

      def dispatch_loop
        loop do
          job = @queue.pop
          if job
            IO.select(nil, @workers).tap do |(_nil, available)|
              available.sample.write(job)
            end
          else
            closed = []
            @workers.each do |worker|
              worker.write([:exit])
              worker.close
              closed << worker
            rescue IO::WaitWritable
              next
            end
            @workers.delete_if(&closed.method(:include?))
            return if @workers.empty?
            IO.select(nil, @workers)
          end
        end
      end

      def push(*args)
        @queue.push(args)
        nil
      end

      def shutdown
        @queue.close
        @dispatcher_thread.join
        @workers.each do |worker|
          _pid, status = Process.wait2(worker.pid)
          return status.exitstatus unless status.success?
        end
        nil
      end
    end
  end
end
