require_relative '../isolation_helper'
require_relative '../../lib/kommando'

class KommandoCommandResultTest < IsolationTest
  include Kommando

  def test_required_success_attributes
    assert_raises(ArgumentError) { CommandResult::Success.new({}) }
    assert_raises(ArgumentError) { CommandResult::Success.new({ command: '' }) }
    assert_raises(ArgumentError) { CommandResult::Success.new({ parameters: {} }) }
  end

  def test_required_failure_attributes
    assert_raises(ArgumentError) { CommandResult::Failure.new({}) }
    assert_raises(ArgumentError) { CommandResult::Failure.new({ error: {} }) }
    assert_raises(ArgumentError) { CommandResult::Failure.new({ command: '' }) }
    assert_raises(ArgumentError) { CommandResult::Failure.new({ parameters: {} }) }
  end

  def test_named_constructors
    assert_instance_of CommandResult::Success, CommandResult.success({ command: '', parameters: {} })
    assert_instance_of CommandResult::Failure, CommandResult.failure({ error: '', command: '', parameters: {} })
  end

  def test_predicates
    success = CommandResult.success({ command: '', parameters: {} })
    failure = CommandResult.failure({ error: '', command: '', parameters: {} })

    assert success.success?
    assert failure.error?
    refute success.error?
    refute failure.success?
  end

  def test_value_attribute
    value = { command: 'DummyCommand', parameters: { a: 1 } }
    error = { error: :some_error, command: 'DummyCommand', parameters: { a: 1 } }
    success = CommandResult.success(value)
    failure = CommandResult.failure(error)

    assert_equal value, success.value
    assert_raises(CommandResult::NonExistentValue) { failure.value }
  end

  def test_error_attribute
    value = { command: 'DummyCommand', parameters: { a: 1 } }
    error = { error: :some_error, command: 'DummyCommand', parameters: { a: 1 } }
    success = CommandResult.success(value)
    failure = CommandResult.failure(error)

    assert_equal error, failure.error
    assert_raises(CommandResult::NonExistentError) { success.error }
  end

  def test_success_pattern_matching
    result = CommandResult.success({ command: 'DummyCommand', parameters: { a: 1 } })

    case result
    in { value: }
      assert true, 'matches any value'
    else
      flunk
    end

    case result
    in { value: 'DummyCommand' }
      assert true, 'matches specific value'
    else
      flunk
    end

    case result
    in { value: 'OtherCommand' }
      flunk
    else
      assert true, 'matches specific value'
    end

    case result
    in { value: value }
      assert_equal 'DummyCommand', value, 'matches any value and assigns it'
    else
      flunk
    end

    case result
    in { value:, command: command, parameters: { a: a } }
      assert_equal 1, a, 'assigns other attributes'
      assert_equal 'DummyCommand', command, 'assigns other attributes'
    else
      flunk
    end

    case result
    in { error: }
      flunk
    else
      assert true, 'does not match error'
    end
  end

  def test_failure_pattern_matching
    result = CommandResult.failure({ error: :some_error, command: 'DummyCommand', parameters: { a: 1 } })

    case result
    in { error: }
      assert true, 'matches any error'
    else
      flunk
    end

    case result
    in { error: :some_error }
      assert true, 'matches specific error'
    else
      flunk
    end

    case result
    in { error: :other_error }
      flunk
    else
      assert true, 'matches specific error'
    end

    case result
    in { error: error }
      assert_equal :some_error, error, 'matches any error and assigns it'
    else
      flunk
    end

    case result
    in { error:, command: command, parameters: { a: a } }
      assert_equal 1, a, 'assigns other attributes'
      assert_equal 'DummyCommand', command, 'assigns other attributes'
    else
      flunk
    end

    case result
    in { value: }
      flunk
    else
      assert true, 'does not match value'
    end
  end
end
