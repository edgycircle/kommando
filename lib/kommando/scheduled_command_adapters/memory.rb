require 'ostruct'

# stravid@2022-01-10: This implementation is currently not threadsafe.
#                     Instead of two arrays we need to use a single one in
#                     combination with a mutex.
module Kommando
  module ScheduledCommandAdapters
    class Memory
      @@scheduled = []
      @@locked_ids = []

      def self.schedule!(command, parameters, handle_at)
        @@scheduled << {
          id: parameters.fetch(:command_id),
          name: command,
          parameters: parameters,
          handle_at: handle_at,
          failures: [],
          wait_for_command_ids: parameters.fetch(:wait_for_command_ids, []),
        }
      end

      def self.fetch!(&block)
        scheduled_ids = @@scheduled.map { |command| command[:id] }

        record = @@scheduled.select do |command|
          next if @@locked_ids.include?(command[:id])
          next if Time.now < command[:handle_at]
          next if command[:wait_for_command_ids].any? { |id| scheduled_ids.include?(id) }

          true
        end.sort do |a, b|
          a[:handle_at] <=> b[:handle_at]
        end.first

        if record
          @@locked_ids.push(record[:id])
          result = block.call(record[:name], record[:parameters])

          if result.success?
            @@scheduled.delete(record)
          else
            record[:failures] = record[:failures].append(result.error)
            record[:handle_at] = record[:handle_at] + 5 * 60
          end

          @@locked_ids.delete(record[:id])
        end
      end

      def self.metrics
        scheduled_ids = @@scheduled.map { |command| command[:id] }

        executable = @@scheduled.select do |command|
          next if @@locked_ids.include?(command[:id])
          next if Time.now < command[:handle_at]
          next if command[:wait_for_command_ids].any? { |id| scheduled_ids.include?(id) }

          true
        end.size

        scheduled = count

        with_failures = @@scheduled.select do |command|
          command[:failures].size > 0
        end.size

        {
          kommando_executable_commands: executable,
          kommando_scheduled_commands: scheduled,
          kommando_scheduled_commands_with_failures: with_failures,
        }
      end

      def self.first
        OpenStruct.new(@@scheduled.first)
      end

      def self.count
        @@scheduled.size
      end

      def self.clear
        @@scheduled = []
        @@locked_ids = []
      end
    end
  end
end
