require 'securerandom'

module Kommando
  module CommandPlugins
    module Execute
      def self.configure(command_klass, *args)
      end

      module ClassMethods
        def execute(dependencies, parameters)
          context = {
            dependencies: dependencies,
            parameters: parameters,
            instance: new,
          }

          context = _before_execute(context)
          return _halt_with_failure(context) if context.key?(:halt)

          context = _execute(context)
          return _halt_with_failure(context) if context.key?(:halt)

          context = _after_execute(context)
          return _halt_with_failure(context) if context.key?(:halt)

          _execute_context_to_result(context)
        end

        def _before_execute(context)
          unless context[:parameters].key?(:command_id)
            context[:parameters] = context[:parameters].merge({ command_id: SecureRandom.uuid })
          end

          context
        end

        def _execute(context)
          context.merge(execute_return_value: context[:instance].handle(context[:dependencies], context[:parameters]))
        rescue StandardError => error
          context.merge(halt: { error: :unhandled_exception, data: error })
        end

        def _after_execute(context)
          case context[:execute_return_value]
          when CommandResult::Failure
            context.merge(halt: context[:execute_return_value])
          else
            context
          end
        end

        def _execute_context_to_result(context)
          CommandResult.success(_execute_context_to_data({}, context))
        end

        def _halt_with_failure(context)
          case context[:halt]
          when CommandResult::Failure
            context[:halt]
          else
            CommandResult.failure(_execute_context_to_data({}, context).merge({ error: context[:halt][:error], details: context[:halt][:data] }))
          end
        end

        def _execute_context_to_data(data, context)
          data.merge(context.slice(:parameters)).merge(command: name)
        end

        private
        def reserved_parameter_keys
          [:command_id]
        end
      end

      module InstanceMethods
      end
    end
  end
end
