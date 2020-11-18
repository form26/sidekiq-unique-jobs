# frozen_string_literal: true

Redis.exists_returns_integer = false

REDIS = Redis.new(url: ENV["REDIS_URL"])

Sidekiq.default_worker_options = {
  backtrace: true,
  retry: true,
}

Sidekiq.client_middleware do |chain|
  chain.add Sidekiq::GlobalId::ClientMiddleware
  chain.add SidekiqUniqueJobs::Middleware::Client
end

Sidekiq.server_middleware do |chain|
  chain.add SidekiqUniqueJobs::Middleware::Server
  chain.add Sidekiq::GlobalId::ServerMiddleware
end

Sidekiq.configure_server do |config|
  config.redis = { url: ENV["REDIS_URL"], driver: :hiredis }
  config.error_handlers << ->(ex, ctx_hash) { p ex, ctx_hash }

  config.death_handlers << lambda do |job, _ex|
    digest = job["lock_digest"]
    SidekiqUniqueJobs::Digests.delete_by_digest(digest) if digest
  end

  # # accepts :expiration (optional)
  Sidekiq::Status.configure_server_middleware config, expiration: 30.minutes

  # # accepts :expiration (optional)
  Sidekiq::Status.configure_client_middleware config, expiration: 30.minutes

  # schedule_file = "config/schedule.yml"

  # if File.exist?(schedule_file)
  #   Sidekiq::Cron::Job.load_from_hash YAML.load_file(schedule_file)
  # end
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV["REDIS_URL"], driver: :hiredis }
  # accepts :expiration (optional)
  Sidekiq::Status.configure_client_middleware config, expiration: 30.minutes
end

Sidekiq.logger       = Sidekiq::Logger.new($stdout)
Sidekiq.logger.level = :info
Sidekiq.log_format = :json if Sidekiq.respond_to?(:log_format)
SidekiqUniqueJobs.configure do |config|
  config.debug_lua       = false
  config.lock_info       = true
  config.logger          = Sidekiq.logger
  config.max_history     = 10_000
  config.reaper          = :lua
  config.reaper_count    = 10_000
  config.reaper_interval = 10
  config.reaper_timeout  = 5
end
Dir[Rails.root.join("app", "workers", "**", "*.rb")].sort.each { |worker| require worker }
