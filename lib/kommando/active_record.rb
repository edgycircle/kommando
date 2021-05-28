require_relative '../kommando'

module Kommando
  class Railtie < Rails::Railtie
    initializer 'kommando.initialize' do
      require_relative './scheduled_command_adapters/active_record'
    end
  end
end
