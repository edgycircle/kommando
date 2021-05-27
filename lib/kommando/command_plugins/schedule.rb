require 'securerandom'

module Kommando
  module CommandPlugins
    module Schedule
      def self.configure(command_klass, *args)
      end

      module ClassMethods
        def schedule(dependencies, parameters)
          unless dependencies.key?(:schedule_adapter)
            raise Command::MissingDependencyError, 'You need to provide the `:schedule_adapter` dependency'
          end

          unless parameters.key?(:handle_at)
            raise Command::MissingParameterError, 'You need to provide the `:handle_at` parameter'
          end

          context = {
            parameters: parameters,
            schedule_adapter: dependencies[:schedule_adapter],
            handle_at: parameters[:handle_at].getutc,
          }

          context = _before_schedule(context)
          return _halt_schedule_with_failure(context) if context.key?(:halt)

          context = _schedule(context)
          return _halt_schedule_with_failure(context) if context.key?(:halt)

          context = _after_schedule(context)
          return _halt_schedule_with_failure(context) if context.key?(:halt)

          _schedule_context_to_result(context)
        end

        def _before_schedule(context)
          unless context[:parameters].key?(:command_id)
            context[:parameters] = context[:parameters].merge({ command_id: SecureRandom.uuid })
          end

          context
        end

        def _schedule(context)
          context.merge(schedule_return_value: context[:schedule_adapter].schedule!(name, context[:parameters], context[:handle_at]))
        end

        def _after_schedule(context)
          context
        end

        def _before_execute(context)
          context[:instance].scheduled_command_results = []
          super(context)
        end

        def _after_execute(context)
          results = context[:instance].scheduled_command_results

          if failed_result = results.find(&:error?)
            super(context.merge(halt: CommandResult.failure({ command: name, parameters: context[:parameters] }.merge({ error: :scheduling_error, details: failed_result.error }))))
          else
            super(context)
          end
        end

        def _schedule_context_to_result(context)
          CommandResult.success(_schedule_context_to_data({}, context))
        end

        def _execute_context_to_data(data, context)
          results = context[:instance].scheduled_command_results
          super(data.merge(scheduled_commands: results.map(&:value)), context)
        end

        def _schedule_context_to_data(data, context)
          data.merge(context.slice(:parameters)).merge(command: name)
        end

        def _halt_schedule_with_failure(context)
          case context[:halt]
          when CommandResult::Failure
            context[:halt]
          else
            CommandResult.failure(_schedule_context_to_data({}, context).merge({ error: context[:halt][:error], details: context[:halt][:data] }))
          end
        end

        private
        def reserved_parameter_keys
          super.concat([:handle_at, :wait_for_command_ids, :command_id]).uniq
        end
      end

      module InstanceMethods
        attr_accessor :scheduled_command_results

        def scheduled(result)
          @scheduled_command_results.push(result)
        end
      end
    end
  end
end
