module Kommando
  module CommandPlugins
    module AutoSchedule
      def self.configure(command_klass, options)
        command_klass.options[:default_handle_at] = options.fetch(:handle_at)
      end

      module ClassMethods
        def schedule(dependencies, parameters)
          super(dependencies, { handle_at: options[:default_handle_at].call }.merge(parameters))
        end
      end
    end
  end
end
