# frozen_string_literal: true

require_relative 'custom_queue_job'

class CustomQueueJobWithFilterMethod < CustomQueueJob
  sidekiq_options unique: :until_executed, unique_args: :args_filter

  def self.args_filter(args)
    args.first
  end
end
