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
      attr_accessor :parameters, :command_name
    end

    def self.fetch!(&block)
      block.call(command_name, parameters)
    end
  end

  class EmptyAdapter
    def self.fetch!(&block)
    end
  end

  class DummyCoordinator
    attr_reader :last_delay

    def schedule_next_run(delay)
      @last_delay = delay
    end
  end

  def test_executes_command
    FullAdapter.parameters = { b: 2 }
    FullAdapter.command_name = TestCommand.name
    coordinator = DummyCoordinator.new
    dependencies = { a: 1 }
    runner = ScheduledCommandRunner.new(coordinator, FullAdapter, dependencies)

    runner.call

    assert_equal dependencies, TestCommand.last_dependencies
    assert_equal FullAdapter.parameters, TestCommand.last_parameters
    assert_equal 0, coordinator.last_delay, 'immediately schedules next run'
  end

  def test_unknown_command
    FullAdapter.parameters = { b: 2 }
    FullAdapter.command_name = 'OldCommand'
    coordinator = DummyCoordinator.new
    dependencies = { a: 1 }
    runner = ScheduledCommandRunner.new(coordinator, FullAdapter, dependencies)

    assert_raises(Command::UnknownCommandError) do
      runner.call
    end
  end

  def test_delays_next_run_if_nothing_was_run
    coordinator = DummyCoordinator.new
    dependencies = { a: 1 }
    runner = ScheduledCommandRunner.new(coordinator, EmptyAdapter, dependencies)

    runner.call

    assert_equal 5, coordinator.last_delay
  end
end
