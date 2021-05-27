require_relative '../../isolation_helper'
require_relative '../../../lib/kommando'

class KommandoCommandPluginsExecuteTest < IsolationTest
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

      return parameters[:result] if parameters.key?(:result)
      raise parameters[:exception] if parameters.key?(:exception)
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

  def test_execute
    parameters = { b: 2, command_id: SecureRandom.uuid }

    TestCommand.execute(complete_dependencies, parameters)

    assert_equal complete_dependencies, TestCommand.last_dependencies, 'passes dependencies to handle'
    assert_equal parameters, TestCommand.last_parameters, 'passes parameters to handle'
  end

  def test_execute_returns_success_result
    parameters = { b: 2, command_id: SecureRandom.uuid }

    result = TestCommand.execute(complete_dependencies, parameters)

    assert result.success?
    assert_equal TestCommand.name, result.value[:command]
    assert_equal parameters, result.value[:parameters]
  end

  def test_execute_generates_a_command_id_if_none_is_provided
    parameters = { b: 2 }

    TestCommand.execute(complete_dependencies, parameters)

    assert_match /^[0-9a-f]{8}-[0-9a-f]{4}-[0-5][0-9a-f]{3}-[089ab][0-9a-f]{3}-[0-9a-f]{12}$/i, TestCommand.last_parameters[:command_id]
  end

  def test_execute_returns_failure_result_from_handler
    failure = CommandResult.failure({ error: :some_error, command: 'TestCommand', parameters: { a: 1 } })
    parameters = { result: failure }

    result = TestCommand.execute(complete_dependencies, parameters)

    assert result.error?
    assert_equal failure.error[:error], result.error[:error]
    assert_equal failure.error[:command], result.error[:command]
    assert_equal failure.error[:command], result.error[:command]
    assert_equal failure.error[:parameters], result.error[:parameters]
  end

  def test_execute_returns_failure_result_instead_of_throwing_exception
    exception = StandardError.new('Some exception')
    parameters = { exception: exception }

    result = TestCommand.execute(complete_dependencies, parameters)

    assert result.error?
    assert_equal :unhandled_exception, result.error[:error]
    assert_equal exception, result.error[:details]
  end
end
