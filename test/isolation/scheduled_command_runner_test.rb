require_relative '../isolation_helper'
require_relative '../../lib/kommando'

class KommandoScheduledCommandRunnerTest < IsolationTest
  include Kommando

  class TestCommand < Command
    class << self
      attr_accessor :last_dependencies, :last_parameters
    end

    def self.execute(dependencies, parameters)
      TestCommand.last_dependencies = dependencies
      TestCommand.last_parameters = parameters

      return parameters[:result] if parameters.key?(:result)
    end
  end

  class FullAdapter
    class << self
      attr_accessor :parameters, :command_name, :fetch_count
    end

    def self.fetch!(&block)
      self.fetch_count += 1
      block.call(command_name, parameters)
    end
  end

  class EmptyAdapter
    class << self
      attr_accessor :parameters, :command_name, :fetch_count
    end

    def self.fetch!(&block)
      self.fetch_count += 1
    end
  end

  def test_executes_command
    FullAdapter.parameters = { b: 2 }
    FullAdapter.command_name = TestCommand.name
    FullAdapter.fetch_count = 0
    dependencies = { a: 1 }
    runner = ScheduledCommandRunner.new(1, FullAdapter, dependencies)

    runner.start

    sleep 0.05 until FullAdapter.fetch_count > 1
    runner.stop_before_next_fetch

    assert_equal dependencies, TestCommand.last_dependencies
    assert_equal FullAdapter.parameters, TestCommand.last_parameters
    assert FullAdapter.fetch_count > 1, 'immediately schedules next run'
  end

  def test_unknown_command
    FullAdapter.parameters = { b: 2 }
    FullAdapter.command_name = 'OldCommand'
    FullAdapter.fetch_count = 0
    dependencies = { a: 1 }
    runner = ScheduledCommandRunner.new(1, FullAdapter, dependencies)

    runner.start

    sleep 0.05 until FullAdapter.fetch_count > 0
    assert runner.stopped?
  end

  def test_delays_next_run_if_nothing_was_run
    dependencies = { a: 1 }
    EmptyAdapter.fetch_count = 0
    runner = ScheduledCommandRunner.new(1, EmptyAdapter, dependencies)

    runner.start

    sleep 0.05 until EmptyAdapter.fetch_count > 0
    sleep 0.25

    assert_equal 1, EmptyAdapter.fetch_count
  end
end
