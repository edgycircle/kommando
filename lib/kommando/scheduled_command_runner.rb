module Kommando
  class ScheduledCommandRunner
    def initialize(coordinator, adapter, dependencies)
      @coordinator = coordinator
      @adapter = adapter
      @dependencies = dependencies
    end

    def call
      fetched_command = false

      @adapter.fetch! do |command_name, parameters|
        unless self.class.const_defined?(command_name)
          raise Command::UnknownCommandError, "Unknown command `#{command_name}`"
        end

        fetched_command = true

        self.class.const_get(command_name).execute(@dependencies, parameters)
      end

      @coordinator.schedule_next_run(fetched_command ? 0 : 5)
    end
  end
end
