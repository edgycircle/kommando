require 'ostruct'
require 'concurrent'

module Kommando
  module ScheduledCommandAdapters
    class Memory
      @@scheduled = []
      @@locked_ids = Concurrent::Array.new

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

          @@locked_ids.push(record[:id])
        end
      end

      def self.first
        OpenStruct.new(@@scheduled.first)
      end

      def self.count
        @@scheduled.size
      end

      def self.clear
        @@scheduled = []
        @@locked_ids = Concurrent::Array.new
      end
    end
  end
end
