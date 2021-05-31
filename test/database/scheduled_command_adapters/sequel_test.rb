require_relative '../../database_helper'

require 'sequel'
DB = Sequel.connect('postgres://@localhost/kommando_test')

require_relative '../../../lib/kommando/scheduled_command_adapters/sequel'
require_relative '../../../lib/kommando'

class KommandoScheduledCommandAdaptersSequelTest < DatabaseTest
  include Kommando

  def setup
    DB.execute('DELETE FROM kommando_scheduled_commands;')
  end

  def teardown
    DB.execute('DELETE FROM kommando_scheduled_commands;')
  end

  def test_schedule_writes_to_database
    command = 'ACommand'
    parameters = { a: 1, command_id: SecureRandom.uuid, wait_for_command_ids: [SecureRandom.uuid] }
    handle_at = Time.now.getutc.round(6)

    ScheduledCommandAdapters::Sequel.schedule!(command, parameters, handle_at)

    record = ScheduledCommandAdapters::Sequel.first

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

    ScheduledCommandAdapters::Sequel.schedule!(command_a, parameters_a, handle_at_a)
    ScheduledCommandAdapters::Sequel.schedule!(command_b, parameters_b, handle_at_b)

    fetched_command = nil
    fetched_parameters = nil

    ScheduledCommandAdapters::Sequel.fetch! do |command, parameters|
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

    ScheduledCommandAdapters::Sequel.schedule!(command, parameters, handle_at)

    fetched_command = nil
    fetched_parameters = nil

    ScheduledCommandAdapters::Sequel.fetch! do |command, parameters|
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

    ScheduledCommandAdapters::Sequel.schedule!(command_a, parameters_a, handle_at_a)
    ScheduledCommandAdapters::Sequel.schedule!(command_b, parameters_b, handle_at_b)

    fetched_command = nil
    fetched_parameters = nil

    ScheduledCommandAdapters::Sequel.fetch! do |command, parameters|
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

    ScheduledCommandAdapters::Sequel.schedule!(command, parameters, handle_at)

    ScheduledCommandAdapters::Sequel.fetch! do |command, parameters|
      CommandResult.success({ command: command, parameters: parameters })
    end

    assert_equal 0, ScheduledCommandAdapters::Sequel.count
  end

  def test_fetch_reschedules_commands_that_failed
    command = 'ACommand'
    parameters = { a: 1, command_id: SecureRandom.uuid }
    handle_at = Time.new(2020, 12, 13, 15, 22).getutc
    error = 'some_error'
    details = { b: 2 }

    ScheduledCommandAdapters::Sequel.schedule!(command, parameters, handle_at)

    ScheduledCommandAdapters::Sequel.fetch! do |command, parameters|
      CommandResult.failure({ error: error, command: command, parameters: parameters, details: details })
    end

    record = ScheduledCommandAdapters::Sequel.first

    assert_equal 1, ScheduledCommandAdapters::Sequel.count
    assert_equal command, record.name
    assert_equal parameters, record.parameters
    assert handle_at < record.handle_at
    assert_equal [{ error: error, command: command, parameters: parameters, details: details }], record.failures
  end

  def test_fetch_locks_scheduled_command
    command = 'ACommand'
    parameters = { a: 1, command_id: SecureRandom.uuid }
    handle_at = Time.new(2020, 12, 13, 15, 22).getutc

    ScheduledCommandAdapters::Sequel.schedule!(command, parameters, handle_at)

    barrier_a = false
    barrier_b = false
    callback_a = false
    callback_b = false

    thread_a = Thread.new do
      ScheduledCommandAdapters::Sequel.fetch! do |command, parameters|
        callback_a = true
        barrier_b = true
        sleep 0.0001 until barrier_a
        CommandResult.success({ command: command, parameters: parameters })
      end
    end

    thread_b = Thread.new do
      sleep 0.0001 until barrier_b

      ScheduledCommandAdapters::Sequel.fetch! do |command, parameters|
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
end
