# frozen_string_literal: true

class WithoutArgumentJob
  include Sidekiq::Worker
  sidekiq_options unique: :until_executed,
                  log_duplicate_payload: true

  def perform
    sleep 20
  end
end
