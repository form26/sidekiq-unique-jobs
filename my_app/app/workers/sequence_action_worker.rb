class SequenceActionWorker
  include Sidekiq::Worker
  include Sidekiq::Status::Worker

  sidekiq_options lock: :until_and_while_executing

  def perform(id)
    sleep 1.minute
    p id
  end
end
