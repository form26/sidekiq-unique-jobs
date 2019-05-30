# frozen_string_literal: true

module SidekiqUniqueJobs
  module Orphans
    #
    # Class DeleteOrphans provides deletion of orphaned digests
    #
    # @note this is a much slower version of the lua script but does not crash redis
    #
    # @author Mikael Henriksson <mikael@zoolutions.se>
    #
    class Reaper
      include SidekiqUniqueJobs::Connection
      include SidekiqUniqueJobs::Script::Caller
      include SidekiqUniqueJobs::Logging

      #
      # Execute deletion of orphaned digests
      #
      # @param [Redis] conn nil a connection to redis
      #
      # @return [void]
      #
      def self.call(conn = nil)
        new(conn).call if conn
        redis { |rcon| new(rcon).call }
      end

      attr_reader :conn, :digests, :scheduled, :retried

      #
      # Initialize a new instance of DeleteOrphans
      #
      # @param [Redis] conn a connection to redis
      #
      def initialize(conn)
        @conn      = conn
        @digests   = SidekiqUniqueJobs::Digests.new
        @scheduled = Redis::SortedSet.new(SCHEDULE)
        @retried   = Redis::SortedSet.new(RETRY)
      end

      #
      # Convenient access to the global configuration
      #
      #
      # @return [SidekiqUniqueJobs::Config]
      #
      def config
        SidekiqUniqueJobs.config
      end

      #
      # The reaper that was configured
      #
      #
      # @return [Symbol]
      #
      def reaper
        config.reaper
      end

      #
      # The number of locks to reap at a time
      #
      #
      # @return [Integer]
      #
      def reaper_count
        config.reaper_count
      end

      #
      # Delete orphaned digests
      #
      #
      # @return [Integer] the number of reaped locks
      #
      def call
        case reaper
        when :ruby
          execute_ruby_reaper
        when :lua
          execute_lua_reaper
        else
          log_fatal(":#{reaper} is invalid for `SidekiqUnqiueJobs.config.reaper`")
        end
      end

      #
      # Executes the ruby reaper
      #
      #
      # @return [Integer] the number of deleted locks
      #
      def execute_ruby_reaper
        BatchDelete.call(orphans, conn)
      end

      #
      # Executes the lua reaper
      #
      #
      # @return [Integer] the number of deleted locks
      #
      def execute_lua_reaper
        call_script(
          :reap_orphans,
          conn,
          keys: [SidekiqUniqueJobs::DIGESTS, SidekiqUniqueJobs::SCHEDULE, SidekiqUniqueJobs::RETRY],
          argv: [reaper_count],
        )
      end

      #
      # Find orphaned digests
      #
      #
      # @return [Array<String>] an array of orphaned digests
      #
      def orphans
        conn.zrevrange(digests.key, 0, -1).each_with_object([]) do |digest, result|
          next if belongs_to_job?(digest)

          result << digest
          break if result.size >= reaper_count
        end
      end

      #
      # Checks if the digest has a matching job.
      #   1. It checks the scheduled set
      #   2. It checks the retry set
      #   3. It goes through all queues
      #
      #
      # @param [String] digest the digest to search for
      #
      # @return [true] when either of the checks return true
      # @return [false] when no job was found for this digest
      #
      def belongs_to_job?(digest)
        scheduled?(digest) || retried?(digest) || enqueued?(digest)
      end

      #
      # Checks if the digest exists in the Sidekiq::ScheduledSet
      #
      # @param [String] digest the current digest
      #
      # @return [true] when digest exists in scheduled set
      #
      def scheduled?(digest)
        in_sorted_set?(SCHEDULE, digest)
      end

      #
      # Checks if the digest exists in the Sidekiq::RetrySet
      #
      # @param [String] digest the current digest
      #
      # @return [true] when digest exists in retry set
      #
      def retried?(digest)
        in_sorted_set?(RETRY, digest)
      end

      #
      # Checks if the digest exists in a Sidekiq::Queue
      #
      # @param [String] digest the current digest
      #
      # @return [true] when digest exists in any queue
      #
      #
      def enqueued?(digest)
        if (result = call_script(:find_digest_in_queues, conn, keys: [digest]))
          log_debug("#{digest} found in #{result}")
          true
        else
          log_debug("#{digest} NOT found in any queues")
        end
      end

      #
      # Checks a sorted set for the existance of this digest
      #
      #
      # @param [String] key the key for the sorted set
      # @param [String] digest the digest to scan for
      #
      # @return [true] when found
      # @return [false] when missing
      #
      def in_sorted_set?(key, digest)
        conn.zscan_each(key, match: "*#{digest}*", count: 1).to_a.any?
      end
    end
  end
end
