# frozen_string_literal: true

RSpec.describe SidekiqUniqueJobs::Lock::BaseLock do
  let(:lock)       { described_class.new(item, redis_pool) }
  let(:item)       { {} }
  let(:redis_pool) { nil }
  let(:locksmith)  { instance_double(SidekiqUniqueJobs::Locksmith) }

  before do
    allow(SidekiqUniqueJobs::Locksmith).to receive(:new).with(item, redis_pool).and_return(locksmith)
  end

  describe '#lock' do
    it 'delegates to locksmith' do
      expect(locksmith).to receive(:lock).with(kind_of(Integer)).and_return(true)
      expect(lock.lock).to eq(true)
    end
  end

  describe '#execute' do
    it 'delegates to locksmith' do
      expect { lock.execute(nil) }
        .to raise_error(NotImplementedError, "#execute needs to be implemented in #{described_class}")
    end
  end

  describe '#unlock' do
    it 'delegates to locksmith' do
      expect(locksmith).to receive(:unlock).with(no_args).and_return('unlocked')
      expect(lock.unlock).to eq('unlocked')
    end
  end

  describe '#delete!' do
    it 'delegates to locksmith' do
      allow(locksmith).to receive(:unlock)
      allow(locksmith).to receive(:delete!).and_return('deleted')

      expect(lock.delete!).to eq('deleted')
    end
  end

  describe '#locked?' do
    it 'delegates to locksmith' do
      allow(locksmith).to receive(:locked?).and_return(true)
      expect(lock.locked?).to eq(true)
    end
  end
end
