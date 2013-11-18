require 'digest'

module SidekiqUniqueJobs
  module Middleware
    module Client
      class UniqueJobs
        attr_reader :item, :worker_class

        def call(worker_class, item, queue)
          @worker_class = worker_class_constantize(worker_class)
          @item = item

          if enabled?
            yield if unique?
          else
            yield
          end
        end

        def unique?
          unique = false

          Sidekiq.redis do |conn|

            conn.watch(payload_hash)

            if conn.get(payload_hash).to_i == 1 ||
              (conn.get(payload_hash).to_i == 2 && item['at'])
              # if the job is already queued, or is already scheduled and
              # we're trying to schedule again, abort
              conn.unwatch
            else
              # if the job was previously scheduled and is now being queued,
              # or we've never seen it before
              expires_at = unique_job_expiration || SidekiqUniqueJobs::Config.default_expiration
              expires_at = ((Time.at(item['at']) - Time.now.utc) + expires_at).to_i if item['at']

              unique = conn.multi do
                # set value of 2 for scheduled jobs, 1 for queued jobs.
                conn.setex(payload_hash, expires_at, item['at'] ? 2 : 1)
              end
            end
          end

          unique
        end

        protected

        # Attempt to constantize a string worker_class argument, always
        # failing back to the original argument.
        def worker_class_constantize(worker_class)
          if worker_class.is_a?(String)
            worker_class.constantize rescue worker_class
          else
            worker_class
          end
        end

        private

        # If the worker or item is marked as unique and testing is not enabled,
        # enable unique jobs.
        def enabled?
          unique_enabled? && !testing_enabled?
        end

        def payload_hash
          SidekiqUniqueJobs::PayloadHelper.get_payload(item['class'], item['queue'], item['args'])
        end

        # When sidekiq/testing is loaded, the Sidekiq::Testing constant is
        # present and testing is enabled.
        def testing_enabled?
          Sidekiq.const_defined?('Testing') && Sidekiq::Testing.enabled?
        end

        def unique_enabled?
          worker_class.get_sidekiq_options['unique'] || item['unique']
        end

        def unique_job_expiration
          worker_class.get_sidekiq_options['unique_job_expiration']
        end

      end
    end
  end
end
