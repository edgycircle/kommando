module Kommando
  class ScheduledCommandWorker
    WAIT_STEP_SIZE = 0.25
    WAIT_LIMIT = 20.0

    def initialize(adapter, dependencies, number_of_runners)
      @number_of_runners = number_of_runners
      @runners = []

      @runners << ScheduledCommandRunner.new(@runners.size + 1, adapter, dependencies) while @runners.size < @number_of_runners

      @self_read, @self_write = IO.pipe
    end

    def start
      @runners.each(&:start)
      IO.select([@self_read])
    end

    def stop
      @runners.each(&:stop_before_next_fetch)

      deadline = now + WAIT_LIMIT

      sleep WAIT_STEP_SIZE until @runners.all?(&:stopped?) || now > deadline

      @runners.reject(&:stopped?).each(&:kill)

      @self_write.puts(:stop)
    end

    private
    def now
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
