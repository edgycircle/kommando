require_relative './command_plugins/base'
require_relative './command_plugins/execute'
require_relative './command_plugins/schedule'

module Kommando
  class Command
    class MissingDependencyError < StandardError; end

    class MissingParameterError < StandardError; end

    class ReservedParameterError < StandardError; end

    class UnknownCommandError < StandardError; end

    @options = {}

    def self.plugin(plugin, *args)
      include plugin::InstanceMethods if defined?(plugin::InstanceMethods)
      extend plugin::ClassMethods if defined?(plugin::ClassMethods)
      plugin.configure(self, *args)
    end

    plugin CommandPlugins::Base
    plugin CommandPlugins::Execute
    plugin CommandPlugins::Schedule
  end
end
