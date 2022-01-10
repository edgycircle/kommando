require_relative '../../isolation_helper'
require_relative '../../../lib/kommando/scheduled_command_adapters/memory'
require_relative '../../../lib/kommando'

class KommandoScheduledCommandAdaptersMemoryTest < IsolationTest
  include Kommando

  def setup
    ScheduledCommandAdapters::Memory.clear
  end

  def teardown
    ScheduledCommandAdapters::Memory.clear
  end

  def test_schedule_writes_to_database
    command = 'ACommand'
    parameters = { a: 1, command_id: SecureRandom.uuid, wait_for_command_ids: [SecureRandom.uuid] }
    handle_at = Time.now.getutc.round(6)

    ScheduledCommandAdapters::Memory.schedule!(command, parameters, handle_at)

    record = ScheduledCommandAdapters::Memory.first

    assert_equal command, record.name
    assert_equal parameters[:command_id], record.id
    assert_equal parameters, record.parameters
    assert_equal handle_at, record.handle_at
    assert_equal parameters[:wait_for_command_ids], record.wait_for_command_ids
    assert_equal [], record.failures
  end

  def test_fetch_yields_callback_with_next_scheduled_command
    command_a = 'ACommand'
    parameters_a = { a: 1, command_id: SecureRandom.uuid }
    handle_at_a = Time.new(2020, 12, 13, 15, 22).getutc
    command_b = 'BCommand'
    parameters_b = { b: 1, command_id: SecureRandom.uuid }
    handle_at_b = Time.new(2020, 12, 13, 15, 21).getutc

    ScheduledCommandAdapters::Memory.schedule!(command_a, parameters_a, handle_at_a)
    ScheduledCommandAdapters::Memory.schedule!(command_b, parameters_b, handle_at_b)

    fetched_command = nil
    fetched_parameters = nil

    ScheduledCommandAdapters::Memory.fetch! do |command, parameters|
      fetched_command = command
      fetched_parameters = parameters
      CommandResult.success({ command: command, parameters: parameters })
    end

    assert_equal command_b, fetched_command
    assert_equal parameters_b, fetched_parameters
  end

  def test_fetch_ignores_commands_scheduled_for_the_future
    command = 'ACommand'
    parameters = { a: 1, command_id: SecureRandom.uuid }
    handle_at = Time.new(Time.now.year + 1)

    ScheduledCommandAdapters::Memory.schedule!(command, parameters, handle_at)

    fetched_command = nil
    fetched_parameters = nil

    ScheduledCommandAdapters::Memory.fetch! do |command, parameters|
      fetched_command = 1
      fetched_parameters = 2
      CommandResult.success(command, {})
    end

    assert_nil fetched_command
    assert_nil fetched_parameters
  end

  def test_fetch_ignores_commands_waiting_on_other_commands
    command_a = 'ACommand'
    parameters_a = { a: 1, command_id: SecureRandom.uuid }
    handle_at_a = Time.new(2020, 12, 13, 15, 22).getutc
    command_b = 'BCommand'
    parameters_b = { b: 1, command_id: SecureRandom.uuid, wait_for_command_ids: [parameters_a[:command_id]] }
    handle_at_b = Time.new(2020, 12, 13, 15, 21).getutc

    ScheduledCommandAdapters::Memory.schedule!(command_a, parameters_a, handle_at_a)
    ScheduledCommandAdapters::Memory.schedule!(command_b, parameters_b, handle_at_b)

    fetched_command = nil
    fetched_parameters = nil

    ScheduledCommandAdapters::Memory.fetch! do |command, parameters|
      fetched_command = command
      fetched_parameters = parameters
      CommandResult.success({ command: command, parameters: parameters })
    end

    assert_equal command_a, fetched_command
    assert_equal parameters_a, fetched_parameters
  end

  def test_fetch_removes_successfully_handled_commands
    command = 'ACommand'
    parameters = { a: 1, command_id: SecureRandom.uuid }
    handle_at = Time.new(2020, 12, 13, 15, 22).getutc

    ScheduledCommandAdapters::Memory.schedule!(command, parameters, handle_at)

    ScheduledCommandAdapters::Memory.fetch! do |command, parameters|
      CommandResult.success({ command: command, parameters: parameters })
    end

    assert_equal 0, ScheduledCommandAdapters::Memory.count
  end

  def test_fetch_reschedules_commands_that_failed
    command = 'ACommand'
    parameters = { a: 1, command_id: SecureRandom.uuid }
    handle_at = Time.new(2020, 12, 13, 15, 22).getutc
    error = 'some_error'
    details = { b: 2 }

    ScheduledCommandAdapters::Memory.schedule!(command, parameters, handle_at)

    ScheduledCommandAdapters::Memory.fetch! do |command, parameters|
      CommandResult.failure({ error: error, command: command, parameters: parameters, details: details })
    end

    record = ScheduledCommandAdapters::Memory.first

    assert_equal 1, ScheduledCommandAdapters::Memory.count
    assert_equal command, record.name
    assert_equal parameters, record.parameters
    assert handle_at < record.handle_at
    assert_equal [{ error: error, command: command, parameters: parameters, details: details }], record.failures
  end

  def test_fetch_locks_scheduled_command
    command = 'ACommand'
    parameters = { a: 1, command_id: SecureRandom.uuid }
    handle_at = Time.new(2020, 12, 13, 15, 22).getutc

    ScheduledCommandAdapters::Memory.schedule!(command, parameters, handle_at)

    barrier_a = false
    barrier_b = false
    callback_a = false
    callback_b = false

    thread_a = Thread.new do
      ScheduledCommandAdapters::Memory.fetch! do |command, parameters|
        callback_a = true
        barrier_b = true
        sleep 0.0001 until barrier_a
        CommandResult.success({ command: command, parameters: parameters })
      end
    end

    thread_b = Thread.new do
      sleep 0.0001 until barrier_b

      ScheduledCommandAdapters::Memory.fetch! do |command, parameters|
        callback_b = true
        CommandResult.success({ command: command, parameters: parameters })
      end

      barrier_a = true
    end

    thread_a.join
    thread_b.join

    assert callback_a
    refute callback_b
  end

  def test_metrics
    command = 'ACommand'
    parameters_a = { command_id: SecureRandom.uuid }
    handle_at_a = Time.new(2020, 12, 13, 15, 22).getutc
    parameters_b = { command_id: SecureRandom.uuid, wait_for_command_ids: [parameters_a[:command_id]] }
    handle_at_b = Time.new(2020, 12, 13, 15, 21).getutc

    ScheduledCommandAdapters::Memory.schedule!(command, parameters_a, handle_at_a)
    ScheduledCommandAdapters::Memory.schedule!(command, parameters_b, handle_at_b)

    ScheduledCommandAdapters::Memory.fetch! do |command, parameters|
      CommandResult.failure({ error: :error, command: command, parameters: parameters, details: :details })
    end

    result = ScheduledCommandAdapters::Memory.metrics

    assert_equal 1, result[:kommando_executable_commands]
    assert_equal 2, result[:kommando_scheduled_commands]
    assert_equal 1, result[:kommando_scheduled_commands_with_failures]
  end
end
