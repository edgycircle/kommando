require 'concurrent'

module Kommando
  class ScheduledCommandWorker
    def initialize(adapter, dependencies, number_of_threads)
      @adapter = adapter
      @dependencies = dependencies
      @number_of_threads = number_of_threads
    end

    def start
      @pool = Concurrent::FixedThreadPool.new(@number_of_threads)
      @number_of_threads.times { schedule_next_run(0) }

      while !@pool.shutdown?
        sleep 1
      end

      @pool.wait_for_termination
    end

    def stop
      @pool.shutdown
    end

    def schedule_next_run(delay)
      Concurrent::ScheduledTask.execute(delay, { executor: @pool }, &ScheduledCommandRunner.new(self, @adapter, @dependencies).method(:call))
    end
  end
end
