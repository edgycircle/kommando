require_relative '../../isolation_helper'
require_relative '../../../lib/kommando'
require 'dry-validation'

class KommandoCommandPluginsValidateTest < IsolationTest
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

  class ValidationlessCommand < Command
    class << self
      attr_accessor :last_dependencies, :last_parameters
    end

    plugin Kommando::CommandPlugins::Validate

    def handle(dependencies, parameters)
      ValidationlessCommand.last_dependencies = dependencies
      ValidationlessCommand.last_parameters = parameters
    end
  end

  class ValidationCommand < Command
    class << self
      attr_accessor :last_dependencies, :last_parameters
    end

    plugin Kommando::CommandPlugins::Validate

    class Schema < Dry::Validation::Contract
      params do
        required(:a).filled(type?: String)
        required(:b).filled(type?: Integer)
      end
    end

    def handle(dependencies, parameters)
      ValidationCommand.last_dependencies = dependencies
      ValidationCommand.last_parameters = parameters
    end
  end

  class InvalidSchemaCommand < Command
    plugin Kommando::CommandPlugins::Validate

    class Schema < Dry::Validation::Contract
      params do
        required(:handle_at).filled(type?: Integer)
      end
    end

    def handle(_, _)
    end
  end

  def complete_dependencies
    { schedule_adapter: TestScheduleAdapter }
  end

  def setup
    ValidationlessCommand.last_dependencies = nil
    ValidationlessCommand.last_parameters = nil
    ValidationCommand.last_dependencies = nil
    ValidationCommand.last_parameters = nil
    TestScheduleAdapter.last_command = nil
    TestScheduleAdapter.last_parameters = nil
    TestScheduleAdapter.last_handle_at = nil
  end

  def test_execute_when_no_schema_is_given
    parameters = { a: 'string', b: 123, command_id: SecureRandom.uuid }

    result = ValidationlessCommand.execute(complete_dependencies, parameters)

    assert result.success?
    assert_equal parameters, ValidationlessCommand.last_parameters
  end

  def test_execute_when_parameters_are_valid
    parameters = { a: 'string', b: 123, command_id: SecureRandom.uuid }

    result = ValidationCommand.execute(complete_dependencies, parameters)

    assert result.success?
    assert_equal parameters, ValidationCommand.last_parameters
  end

  def test_execute_when_parameters_are_invalid
    parameters = { a: 123, b: 'string' }
    expected_validation_error = { a: ['must be String'], b: ['must be Integer'] }

    result = ValidationCommand.execute(complete_dependencies, parameters)

    assert result.error?
    assert_equal :schema_error, result.error[:error]
    assert_equal expected_validation_error, result.error[:details]
    assert_nil ValidationCommand.last_parameters
  end

  def test_schedule_when_parameters_are_valid
    parameters = { a: 'string', b: 1234, handle_at: Time.now, command_id: SecureRandom.uuid }

    result = ValidationCommand.schedule(complete_dependencies, parameters)

    assert result.success?
    assert_equal parameters, TestScheduleAdapter.last_parameters
  end

  def test_schedule_when_parameters_are_invalid
    parameters = { a: 123, b: 'string', handle_at: Time.now, command_id: SecureRandom.uuid }
    expected_validation_error = { a: ['must be String'], b: ['must be Integer'] }

    result = ValidationCommand.schedule(complete_dependencies, parameters)

    assert result.error?
    assert_equal :schema_error, result.error[:error]
    assert_equal expected_validation_error, result.error[:details]
    assert_nil TestScheduleAdapter.last_command
    assert_nil TestScheduleAdapter.last_parameters
  end

  def test_schedule_prevents_reserved_parameter_from_being_used_in_schema
    assert_raises(Command::ReservedParameterError) do
      InvalidSchemaCommand.schedule(complete_dependencies, { handle_at: Time.now })
    end
  end

  def test_execute_prevents_reserved_parameter_from_being_used_in_schema
    assert_raises(Command::ReservedParameterError) do
      InvalidSchemaCommand.execute(complete_dependencies, { handle_at: Time.now })
    end
  end
end
