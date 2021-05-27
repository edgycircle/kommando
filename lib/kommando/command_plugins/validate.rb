module Kommando
  module CommandPlugins
    module Validate
      def self.configure(command_klass, *args)
      end

      module ClassMethods
        def _before_execute(context)
          if const_defined?('Schema')
            schema_keys = const_get('Schema').schema.key_map.map(&:name).map(&:to_sym)

            if forbidden_key = reserved_parameter_keys.find { |key| schema_keys.include?(key) }
              raise Command::ReservedParameterError, "The `#{forbidden_key}` parameter is reserved and cannot be used in command schema"
            end

            reserved_parameters = context[:parameters].slice(*reserved_parameter_keys)
            validation_result = const_get('Schema').new.call(context[:parameters])

            if validation_result.success?
              super(context.merge(parameters: validation_result.to_h.merge(reserved_parameters)))
            else
              super(context.merge(halt: { error: :schema_error, data: validation_result.errors.to_h }))
            end
          else
            super(context)
          end
        end

        def _before_schedule(context)
          if const_defined?('Schema')
            schema_keys = const_get('Schema').schema.key_map.map(&:name).map(&:to_sym)

            if forbidden_key = reserved_parameter_keys.find { |key| schema_keys.include?(key) }
              raise Command::ReservedParameterError, "The `#{forbidden_key}` parameter is reserved and cannot be used in command schema"
            end

            reserved_parameters = context[:parameters].slice(*reserved_parameter_keys)
            validation_result = const_get('Schema').new.call(context[:parameters])

            if validation_result.success?
              super(context.merge(parameters: validation_result.to_h.merge(reserved_parameters)))
            else
              super(context.merge(halt: { error: :schema_error, data: validation_result.errors.to_h }))
            end
          else
            super(context)
          end
        end
      end
    end
  end
end
