# frozen_string_literal: true

require "spec_helper"

RSpec.describe SidekiqUniqueJobs::Locksmith, redis: :redis do
  let(:locksmith_one)   { described_class.new(item_one) }
  let(:locksmith_two)   { described_class.new(item_two) }

  let(:jid_one)         { "maaaahjid" }
  let(:jid_two)         { "jidmayhem" }
  let(:lock_expiration) { nil }
  let(:lock_type)       { "until_executed" }
  let(:unique_digest)   { "uniquejobs:randomvalue" }
  let(:item_one) do
    {
      "jid" => jid_one,
      "unique_digest" => unique_digest,
      "lock_expiration" => lock_expiration,
      "lock" => lock_type,
    }
  end
  let(:item_two) { item_one.merge("jid" => jid_two) }

  shared_examples_for "a lock" do
    it "is unlocked from the start" do
      expect(locksmith_one.locked?).to eq(false)
    end

    it "locks and unlocks" do
      locksmith_one.lock(1)
      expect(locksmith_one.locked?).to eq(true)
      locksmith_one.unlock
      expect(locksmith_one.locked?).to eq(false)
    end

    it "does not lock twice as a mutex" do
      expect(locksmith_one.lock(0)).to be_truthy
      expect(locksmith_two.lock(0)).to eq(nil)
    end

    it "executes the given code block" do
      code_executed = false
      locksmith_one.lock(1) do
        code_executed = true
      end
      expect(code_executed).to eq(true)
    end

    it "passes an exception right through" do
      expect do
        locksmith_one.lock(1) do
          raise Exception, "redis lock exception" # rubocop:disable Lint/RaiseException
        end
      end.to raise_error(Exception, "redis lock exception")
    end

    it "does not leave the lock locked after raising an exception" do
      expect do
        locksmith_one.lock(1) do
          raise Exception, "redis lock exception" # rubocop:disable Lint/RaiseException
        end
      end.to raise_error(Exception, "redis lock exception")

      expect(locksmith_one.locked?).to eq(false)
    end

    it "returns the value of the block if block-style locking is used" do
      block_value = locksmith_one.lock(1) do
        42
      end
      expect(block_value).to eq(42)
    end

    it "disappears without a trace when calling `delete!`" do
      original_key_size = keys.size

      locksmith_one.lock
      locksmith_one.delete!

      expect(keys.size).to eq(original_key_size)
    end

    it "does not block when the timeout is zero" do
      did_we_get_in = false

      locksmith_one.lock do
        locksmith_two.lock(0) do
          did_we_get_in = true
        end
      end

      expect(did_we_get_in).to be false
    end

    it "is locked when the timeout is zero" do
      locksmith_one.lock(0) do
        expect(locksmith_one.locked?).to be true
      end
      expect(locksmith_one.locked?).to eq false
    end
  end

  describe "lock with expiration" do
    let(:lock_expiration) { 3 }
    let(:lock_type)       { :while_executing }

    it_behaves_like "a lock"

    context "when lock_type is until_expired" do
      let(:lock_type) { :until_expired }

      it "prevents other processes from locking" do
        locksmith_one.lock

        expect(ttl("uniquejobs:randomvalue:EXISTS")).to eq(3)

        # PLEASE keep this spec. It verifies that the next lock
        #   doesn't persist the exist_key of another lock
        sleep 1

        expect(ttl("uniquejobs:randomvalue:EXISTS")).to eq(2)
        expect(locksmith_two.lock(0)).to eq(nil)
        expect(ttl("uniquejobs:randomvalue:EXISTS")).to eq(2)

        expect(unique_digests).to match_array([])
        expect(unique_keys).to match_array(%w[
                                             uniquejobs:randomvalue:EXISTS
                                             uniquejobs:randomvalue:GRABBED
                                           ])
      end

      it "expires the expected keys" do
        locksmith_one.lock
        expect(unique_digests).to match_array([])
        expect(unique_keys).to match_array(%w[
                                             uniquejobs:randomvalue:EXISTS
                                             uniquejobs:randomvalue:GRABBED
                                           ])

        expect(ttl("uniquejobs:randomvalue:EXISTS")).to eq(3)
        expect(ttl("uniquejobs:randomvalue:GRABBED")).to eq(3)
      end
    end

    context "when lock_type is anything else than until_expired" do
      let(:lock_type) { :until_executed }

      it "expires the expected keys" do
        locksmith_one.lock
        expect(unique_digests).to match_array(["uniquejobs:randomvalue"])
        expect(unique_keys).to match_array(%w[
                                             uniquejobs:randomvalue:EXISTS
                                             uniquejobs:randomvalue:GRABBED
                                           ])
        expect(ttl("uniquejobs:randomvalue:EXISTS")).to eq(-1)
        expect(ttl("uniquejobs:randomvalue:GRABBED")).to eq(-1)

        locksmith_one.unlock

        expect(ttl("uniquejobs:randomvalue:EXISTS")).to eq(3)
        expect(ttl("uniquejobs:randomvalue:GRABBED")).to eq(-2)
      end
    end

    it "deletes the expected keys" do
      locksmith_one.lock
      expect(unique_digests).to match_array(["uniquejobs:randomvalue"])
      expect(unique_keys).to match_array(%w[
                                           uniquejobs:randomvalue:EXISTS
                                           uniquejobs:randomvalue:GRABBED
                                         ])
      locksmith_one.delete!
      expect(unique_digests).to match_array([])
      expect(unique_keys).to match_array(%w[])
    end

    it "expires keys" do
      Sidekiq.redis(&:flushdb)
      locksmith_one.lock
      keys = unique_keys
      expect(unique_keys).not_to include(keys)
    end

    it "expires keys after unlocking" do
      Sidekiq.redis(&:flushdb)
      locksmith_one.lock do
        # noop
      end
      keys = unique_keys
      expect { unique_keys }.to eventually_not include(keys)
    end
  end

  # describe 'lock without staleness checking' do
  #   it_behaves_like 'a lock'

  #   it 'can dynamically add resources' do
  #     locksmith_one.lock

  #     3.times do
  #       locksmith_one.unlock
  #     end

  #     expect(locksmith_one.available_count).to eq(4)

  #     locksmith_one.wait(1)
  #     locksmith_one.wait(1)
  #     locksmith_one.wait(1)

  #     expect(locksmith_one.available_count).to eq(1)
  #   end

  #   stale clients and concurrency removed in a0cff5bc42edbe7190d6ede7e7f845074d2d7af6
  #   shared_examples 'can release stale clients' do
  #     # TODO: This spec is flaky and should be improved to not use sleeps
  #     it 'can have stale locks released by a third process', :retry do
  #       watchdog = described_class.new(item_one.merge('stale_client_timeout' => 0.5))
  #       locksmith_one.lock

  #       watchdog.release_stale_locks
  #       expect(locksmith_one.locked?).to eq(true)

  #       sleep 0.6
  #       watchdog.release_stale_locks

  #       expect(locksmith_one.locked?).to eq(false)
  #     end
  #   end

  #   context 'when redis version < 3.2', redis_ver: '<= 3.2' do
  #     before { allow(SidekiqUniqueJobs).to receive(:redis_version).and_return('3.1') }

  #     it_behaves_like 'can release stale clients'
  #   end

  #   context 'when redis version >= 3.2' do
  #     before { allow(SidekiqUniqueJobs).to receive(:redis_version).and_return('3.2') }

  #     it_behaves_like 'can release stale clients'
  #   end
  # end

  describe "current_time" do
    let(:lock_stale_client_timeout) { 5 }

    before do
      Timecop.freeze(Time.local(1990))
    end

    it "with time support should return a different time than frozen time" do
      expect(locksmith_one.send(:current_time)).not_to eq(Time.now)
    end
  end
end
