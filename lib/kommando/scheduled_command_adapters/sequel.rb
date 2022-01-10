require 'sequel'

module Kommando
  module ScheduledCommandAdapters
    Sequel::Model.db.extension :pg_array
    Sequel::Model.db.extension :pg_json

    class Sequel < ::Sequel::Model(:kommando_scheduled_commands)
      unrestrict_primary_key

      def self.schedule!(command, parameters, handle_at)
        create({
          id: parameters.fetch(:command_id),
          name: command,
          parameters: JSON.generate(parameters),
          handle_at: handle_at,
          failures: ::Sequel.pg_array([], :json),
          wait_for_command_ids: ::Sequel.pg_array(parameters.fetch(:wait_for_command_ids, []), :uuid),
        })
      end

      def self.fetch!(&block)
        db.transaction do
          record = lock_style("FOR UPDATE OF #{table_name} SKIP LOCKED").
            where(::Sequel.lit('TIMEZONE(\'UTC\', NOW()) >= handle_at')).
            exclude(::Sequel.lit("wait_for_command_ids && (SELECT array_agg(id) FROM #{table_name})")).
            order(::Sequel.asc(:handle_at)).
            limit(1).
            first

          if record
            result = block.call(record.name, record.parameters)

            if result.success?
              record.destroy
            else
              failures = record.failures.append(result.error).map do |failure|
                JSON.generate(failure)
              end

              record.update({
                failures: ::Sequel.pg_array(failures, :json),
                handle_at: (record.handle_at + 5 * 60).getutc,
              })
            end
          end
        end
      end

      def self.metrics
        executable = where(::Sequel.lit('TIMEZONE(\'UTC\', NOW()) >= handle_at')).
          exclude(::Sequel.lit("wait_for_command_ids && (SELECT array_agg(id) FROM #{table_name})")).
          count

        scheduled = count

        with_failures = where(::Sequel.lit('array_length(failures, 1) > 0')).count

        {
          kommando_executable_commands: executable,
          kommando_scheduled_commands: scheduled,
          kommando_scheduled_commands_with_failures: with_failures,
        }
      end

      def parameters
        @parameters ||= deep_symbolize(super)
      end

      def failures
        @failures ||= deep_symbolize(super)
      end

      def handle_at
        offset = super.gmt_offset
        super.dup.gmtime + offset
      end

      private
      def deep_symbolize(original)
        case original
        when ::Sequel::Postgres::PGArray, Array
          original.map do |item|
            deep_symbolize(item)
          end
        when ::Sequel::Postgres::JSONHash, Hash
          original.map do |key, value|
            [key.to_sym, deep_symbolize(value)]
          end.to_h
        else
          original
        end
      end
    end
  end
end
