require_relative '../../isolation_helper'
require_relative '../../../lib/kommando'

class KommandoCommandPluginsAutoScheduleTest < IsolationTest
  include Kommando

  class TestScheduleAdapter
    class << self
      attr_accessor :last_command, :last_parameters, :last_handle_at
    end

    def self.schedule!(command, parameters, handle_at)
      TestScheduleAdapter.last_command = command
      TestScheduleAdapter.last_parameters = parameters
      TestScheduleAdapter.last_handle_at = handle_at
    end
  end

  DEFAULT_HANDLE_AT = Time.now

  class TestCommand < Command
    plugin Kommando::CommandPlugins::AutoSchedule, { handle_at: -> { DEFAULT_HANDLE_AT } }

    class << self
      attr_accessor :last_dependencies, :last_parameters
    end

    def handle(dependencies, parameters)
      TestCommand.last_dependencies = dependencies
      TestCommand.last_parameters = parameters

      scheduled(parameters[:child_command_result]) if parameters.key?(:child_command_result)
    end
  end

  def complete_dependencies
    { schedule_adapter: TestScheduleAdapter }
  end

  def setup
    TestCommand.last_dependencies = nil
    TestCommand.last_parameters = nil
    TestScheduleAdapter.last_command = nil
    TestScheduleAdapter.last_parameters = nil
    TestScheduleAdapter.last_handle_at = nil
  end

  def test_auto_schedule_provides_default_handle_at_parameter
    parameters = { b: 2, command_id: SecureRandom.uuid }

    result = TestCommand.schedule(complete_dependencies, parameters)

    assert result.success?
    assert_equal TestCommand.name, result.value[:command]
    assert_equal TestCommand.name, TestScheduleAdapter.last_command
    assert_equal parameters.merge({ handle_at: DEFAULT_HANDLE_AT }), TestScheduleAdapter.last_parameters
    assert_equal DEFAULT_HANDLE_AT, TestScheduleAdapter.last_handle_at
  end
end
