require_relative '../../isolation_helper'
require_relative '../../../lib/kommando'

class KommandoCommandPluginsScheduleTest < IsolationTest
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

  class TestCommand < Command
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

  def test_schedule_requires_schedule_adapter_dependency
    incomplete_dependencies = {}
    parameters = { b: 2, handle_at: Time.now }

    assert_raises(Command::MissingDependencyError) do
      TestCommand.schedule(incomplete_dependencies, parameters)
    end
  end

  def test_schedule_requires_handle_at_parameter
    parameters = { b: 2 }

    assert_raises(Command::MissingParameterError) do
      TestCommand.schedule(complete_dependencies, parameters)
    end
  end

  def test_schedule
    handle_at = Time.now
    parameters = { b: 2, handle_at: handle_at, command_id: SecureRandom.uuid }

    result = TestCommand.schedule(complete_dependencies, parameters)

    assert result.success?
    assert_equal TestCommand.name, result.value[:command]
    assert_equal TestCommand.name, TestScheduleAdapter.last_command
    assert_equal parameters, TestScheduleAdapter.last_parameters
    assert_equal handle_at, TestScheduleAdapter.last_handle_at
  end

  def test_schedule_generates_a_command_id_if_none_is_provided
    parameters = { b: 2, handle_at: Time.now }

    TestCommand.schedule(complete_dependencies, parameters)

    assert_match /^[0-9a-f]{8}-[0-9a-f]{4}-[0-5][0-9a-f]{3}-[089ab][0-9a-f]{3}-[0-9a-f]{12}$/i, TestScheduleAdapter.last_parameters[:command_id]
  end

  def test_scheduled_tracks_scheduled_child_commands
    child_parameters = { c: 3 }
    child_command = 'ChildCommand'
    child_command_result = CommandResult.success({
      command: child_command,
      parameters: child_parameters,
    })
    parameters = { child_command_result: child_command_result }

    result = TestCommand.execute(complete_dependencies, parameters)

    assert result.success?
    assert_equal 1, result.value[:scheduled_commands].size
    assert_equal child_command, result.value[:scheduled_commands][0][:command]
    assert_equal child_parameters, result.value[:scheduled_commands][0][:parameters]
  end

  def test_failed_scheduled_command_leads_to_failure_for_parent
    child_parameters = { c: 3 }
    child_command = 'ChildCommand'
    child_error = :some_error
    child_error_details = { some_data: 1 }
    child_command_result = CommandResult.failure({
      error: child_error,
      command: child_command,
      parameters: child_parameters,
      details: child_error_details,
    })
    parameters = { child_command_result: child_command_result }

    result = TestCommand.execute(complete_dependencies, parameters)

    assert result.error?
    assert_equal :scheduling_error, result.error[:error]
    # FIXME: Rethink how command result works and what properties it has.
    # assert_equal child_command, result.data[:command]
    # assert_equal child_parameters, result.data[:parameters]
    assert_equal child_error, result.error[:details][:error]
    assert_equal child_error_details, result.error[:details][:details]
  end

  def test_schedule_normalizes_handle_at_to_utc
    non_utc_handle_at = Time.new(2020, 12, 12, 15, 45, 0, '+01:00')

    result = TestCommand.schedule(complete_dependencies, { handle_at: non_utc_handle_at })

    assert TestScheduleAdapter.last_handle_at.utc?
  end
end
