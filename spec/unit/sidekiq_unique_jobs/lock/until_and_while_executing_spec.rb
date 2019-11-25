# frozen_string_literal: true

require "spec_helper"
RSpec.describe SidekiqUniqueJobs::Lock::UntilAndWhileExecuting do
  include_context "with a stubbed locksmith"
  let(:lock)     { described_class.new(item, callback) }
  let(:callback) { -> {} }
  let(:item) do
    {
      "jid" => "maaaahjid",
      "class" => "UntilAndWhileExecutingJob",
      "lock" => "until_and_while_executing",
      "args" => ["one"],
    }
  end

  describe "#execute" do
    let(:runtime_lock) { instance_spy(SidekiqUniqueJobs::Lock::WhileExecuting) }

    before do
      allow(lock).to receive(:unlock).and_return(unlocked)
      allow(lock).to receive(:runtime_lock).and_return(runtime_lock)
      allow(runtime_lock).to receive(:execute).and_yield
    end

    context "when unlock succeeds" do
      let(:unlocked) { true }

      it "unlocks the unique key before yielding" do
        inside_block_value = false

        lock.execute { inside_block_value = true }
        expect(inside_block_value).to eq(true)

        expect(lock).to have_received(:unlock)
        expect(runtime_lock).to have_received(:execute)
      end
    end

    context "when unlock fails" do
      let(:unlocked) { false }

      it "unlocks the unique key before yielding" do
        inside_block_value = false
        lock.execute { inside_block_value = true }
        expect(inside_block_value).to eq(false)

        expect(lock).to have_received(:unlock)
        expect(runtime_lock).not_to have_received(:execute)
      end
    end
  end

  describe "#runtime_lock" do
    subject(:runtime_lock) { lock.runtime_lock }

    it { is_expected.to be_a(SidekiqUniqueJobs::Lock::WhileExecuting) }

    it "initializes with the right arguments" do
      allow(SidekiqUniqueJobs::Lock::WhileExecuting).to receive(:new)
      runtime_lock

      expect(SidekiqUniqueJobs::Lock::WhileExecuting)
        .to have_received(:new)
        .with(item, callback, redis_pool)
    end
  end
end
