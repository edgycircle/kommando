module Kommando
  class ScheduledCommandRunner
    JITTER = 0.5
    PAUSE = 5.0

    def initialize(number, adapter, dependencies)
      @number = number
      @adapter = adapter
      @dependencies = dependencies
      @thread = nil
      @stop_before_next_fetch = false
      @stopped = false
    end

    def start
      @thread ||= start_thread("runner-#{@number}", &method(:run))
    end

    def stop_before_next_fetch
      @stop_before_next_fetch = true
    end

    def stopped?
      @stopped
    end

    def kill
      @thread.kill
    end

    private
    def start_thread(name, &block)
      Thread.new do
        yield
      end
    end

    def run
      fetch until @stop_before_next_fetch
      @stopped = true
    rescue StandardError => exception
      @stopped = true
      raise exception
    end

    def fetch
      immediately_fetch_again = false

      @adapter.fetch! do |command_name, parameters|
        unless self.class.const_defined?(command_name)
          raise Command::UnknownCommandError, "Unknown command `#{command_name}`"
        end

        immediately_fetch_again = true

        self.class.const_get(command_name).execute(@dependencies, parameters)
      end

      sleep sleep_duration_after_empty_fetch unless immediately_fetch_again
    end

    def sleep_duration_after_empty_fetch
      rand((PAUSE - JITTER)..(PAUSE + JITTER))
    end
  end
end
