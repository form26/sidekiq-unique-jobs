# frozen_string_literal: true

class SlowUntilExecutingWorker
  include Sidekiq::Worker
  include Sidekiq::Status::Worker
  sidekiq_options lock: :until_executing,
                  queue: :default,
                  unique_args: (lambda do |args|
                    [args.first]
                  end)

  def perform(some_args)
    SidekiqUniqueJobs.with_context(self.class.name) do
      SidekiqUniqueJobs.logger.debug { "#{__method__}(#{some_args})" }
    end
    sleep 15
  end
end
