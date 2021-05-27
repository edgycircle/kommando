module Kommando
  class CommandResult
    class NonExistentError < StandardError; end

    class NonExistentValue < StandardError; end

    def self.success(value)
      Success.new(value)
    end

    def self.failure(error)
      Failure.new(error)
    end

    class Success
      attr_reader :value

      def initialize(value)
        raise ArgumentError, 'missing `:command` key' unless value.key?(:command)
        raise ArgumentError, 'missing `:parameters` key' unless value.key?(:parameters)
        @value = value
      end

      def error
        raise NonExistentError, 'Success results do not have errors'
      end

      def success?
        true
      end

      def error?
        false
      end

      def deconstruct_keys(_)
        { value: @value[:command] }.merge(@value)
      end
    end

    class Failure
      attr_reader :error

      def initialize(error)
        raise ArgumentError, 'missing `:error` key' unless error.key?(:error)
        raise ArgumentError, 'missing `:command` key' unless error.key?(:command)
        raise ArgumentError, 'missing `:parameters` key' unless error.key?(:parameters)
        @error = error
      end

      def value
        raise NonExistentValue, 'Failure results do not have values'
      end

      def success?
        false
      end

      def error?
        true
      end

      def deconstruct_keys(_)
        { error: error }.merge(@error)
      end
    end
  end
end
