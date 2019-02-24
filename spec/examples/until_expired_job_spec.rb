# frozen_string_literal: true

require "spec_helper"
RSpec.describe UntilExpiredJob do
  it_behaves_like "sidekiq with options" do
    let(:options) do
      {
        "lock_expiration" => 1,
        "lock_timeout" => 0,
        "retry" => true,
        "lock" => :until_expired,
      }
    end
  end

  it_behaves_like "a performing worker" do
    let(:args) { "one" }
  end

  describe "client middleware" do
    context "when job is delayed" do
      before { described_class.perform_in(60, 1, 2) }

      it "rejects new scheduled jobs" do
        expect(1).to be_enqueued_in("customqueue")
        described_class.perform_in(3600, 1, 2)
        expect(1).to be_enqueued_in("customqueue")
        expect(1).to be_scheduled_at(Time.now.to_f + 2 * 60)
      end

      it "rejects new jobs" do
        described_class.perform_async(1, 2)
        expect(1).to be_enqueued_in("customqueue")
      end

      it "allows duplicate messages to different queues" do
        expect(1).to be_enqueued_in("customqueue2")
        with_sidekiq_options_for(described_class, queue: "customqueue2") do
          described_class.perform_async(1, 2)
          expect(1).to be_enqueued_in("customqueue2")
        end
      end

      it "sets keys to expire as per configuration" do
        lock_expiration = described_class.get_sidekiq_options["lock_expiration"]
        unique_keys.each do |key|
          next if key.include?(":GRABBED")

          expect(ttl(key)).to be_within(1).of(lock_expiration + 60)
        end
      end
    end

    context "when job is pushed" do
      before { described_class.perform_async(1, 2) }

      it "rejects new scheduled jobs" do
        expect(1).to be_enqueued_in("customqueue")
        described_class.perform_in(60, 1, 2)
        expect(1).to be_enqueued_in("customqueue")
        expect(0).to be_scheduled_at(Time.now.to_f + 2 * 60)
      end

      it "rejects new jobs" do
        expect(1).to be_enqueued_in("customqueue")
        described_class.perform_async(1, 2)
        expect(1).to be_enqueued_in("customqueue")
      end

      it "allows duplicate messages to different queues" do
        expect(1).to be_enqueued_in("customqueue")
        expect(0).to be_enqueued_in("customqueue2")
        with_sidekiq_options_for(described_class, queue: "customqueue2") do
          described_class.perform_async(1, 2)
          expect(1).to be_enqueued_in("customqueue2")
        end
      end

      it "sets keys to expire as per configuration" do
        lock_expiration = described_class.get_sidekiq_options["lock_expiration"]
        unique_keys.each do |key|
          next if key.include?(":GRABBED")

          expect(ttl(key)).to be_within(1).of(lock_expiration)
        end
      end
    end
  end
end
