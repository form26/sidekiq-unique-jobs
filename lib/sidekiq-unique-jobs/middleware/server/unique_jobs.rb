require 'digest'

module SidekiqUniqueJobs
  module Middleware
    module Server
      class UniqueJobs
        def call(worker, item, queue)
          unlock_order = worker.class.get_sidekiq_options['unique_unlock_order'] ||
            SidekiqUniqueJobs::Config.default_unlock_order

          lock_key = payload_hash(item)

          unlocked = unlock_order == :before_yield ? unlock(lock_key).inspect : 0

          yield
        ensure
          if unlock_order == :after_yield || !defined? unlocked || unlocked != 1
            unlock(lock_key)
          end
        end

        protected

        def payload_hash(item)
          SidekiqUniqueJobs::PayloadHelper.get_payload(item['class'], item['queue'], item['args'])
        end

        def unlock(payload_hash)
          Sidekiq.redis {|conn| conn.del(payload_hash) }
        end

        def logger
          Sidekiq.logger
        end
      end
    end
  end
end
