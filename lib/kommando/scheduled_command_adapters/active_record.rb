require 'active_record'

module Kommando
  module ScheduledCommandAdapters
    class ActiveRecord < ::ActiveRecord::Base
      self.table_name = 'kommando_scheduled_commands'

      def self.schedule!(command, parameters, handle_at)
        create!({
          id: parameters.fetch(:command_id),
          name: command,
          parameters: parameters,
          handle_at: handle_at,
          failures: [],
          wait_for_command_ids: parameters.fetch(:wait_for_command_ids, []),
        })
      end

      def self.fetch!(&block)
        transaction do
          record = lock('FOR UPDATE SKIP LOCKED').
            where('TIMEZONE(\'UTC\', NOW()) >= handle_at').
            where.not("wait_for_command_ids && (SELECT array_agg(id) FROM #{table_name})").
            order(handle_at: :asc).
            limit(1).
            first

          if record
            result = block.call(record.name, record.parameters)

            if result.success?
              record.destroy
            else
              record.update!({
                failures: record.failures.append(result.error),
                handle_at: (record.handle_at + 5.minutes).getutc,
              })
            end
          end
        end
      end

      def parameters
        @parameters ||= super.deep_symbolize_keys!
      end

      def failures
        @failures ||= super.map(&:deep_symbolize_keys!)
      end
    end
  end
end
