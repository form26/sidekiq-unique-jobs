# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SidekiqUniqueJobs::Unlockable, redis: :redis do
  def item_with_digest
    SidekiqUniqueJobs::UniqueArgs.digest(item)
    item
  end
  let(:item) do
    { 'class' => MyUniqueJob,
      'queue' => 'customqueue',
      'args' => [1, 2] }
  end

  let(:unique_digest) { item_with_digest[SidekiqUniqueJobs::UNIQUE_DIGEST_KEY] }

  describe '.unlock' do
    subject { described_class.unlock(item_with_digest) }

    let(:expected_keys) do
      %W[#{unique_digest}:EXISTS #{unique_digest}:GRABBED]
    end

    specify do
      expect(SidekiqUniqueJobs::Util.keys.count).to eq(0)
      Sidekiq::Client.push(item_with_digest)

      expect(SidekiqUniqueJobs::Util.keys.count).to eq(2)

      subject

      expect(SidekiqUniqueJobs::Util.keys.count).to eq(2)
    end
  end

  describe '.delete!' do
    subject { described_class.delete!(item_with_digest) }

    specify do
      expect(SidekiqUniqueJobs::Util.keys.count).to eq(0)
      Sidekiq::Client.push(item_with_digest)

      expect(SidekiqUniqueJobs::Util.keys.count).to eq(2)

      subject

      expect(SidekiqUniqueJobs::Util.keys.count).to eq(0)
    end
  end
end
