module Kommando
  module CommandPlugins
    module Base
      def self.configure(command_klass, *args)
      end

      module ClassMethods
        attr_reader :options

        def inherited(subclass)
          super
          subclass.instance_variable_set(:@options, options.dup)
        end
      end
    end
  end
end
