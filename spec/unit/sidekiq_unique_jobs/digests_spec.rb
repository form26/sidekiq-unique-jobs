# frozen_string_literal: true

require "spec_helper"
RSpec.describe SidekiqUniqueJobs::Digests, redis: :redis do
  shared_context "with a regular job" do
    let(:expected_keys) do
      %w[
        uniquejobs:e739dadc23533773b920936336341d01
        uniquejobs:56c68cab5038eb57959538866377560d
        uniquejobs:8d9e83be14c033be4496295ec2740b91
        uniquejobs:23e8715233c2e8f7b578263fcb8ac657
        uniquejobs:6722965def15faf3c45cb9e66f994a49
        uniquejobs:5bdd20fbbdda2fc28d6461e0eb1f76ee
        uniquejobs:c658060a30b761bb12f2133cb7c3f294
        uniquejobs:b34294c4802ee2d61c9e3e8dd7f2bab4
        uniquejobs:06c3a5b63038c7b724b8603bb02ace99
        uniquejobs:62c11d32fd69c691802579682409a483
      ]
    end

    before do
      (1..10).each do |arg|
        MyUniqueJob.perform_async(arg, arg)
      end
    end
  end

  shared_context "with a runtime job" do
    before do
      (1..10).each do |arg|
        SimulateLock.lock_while_executing("uniquejobs:abcde#{arg}", arg.to_s)
      end
    end

    let(:expected_keys) do
      %w[
        uniquejobs:abcde1:RUN
        uniquejobs:abcde10:RUN
        uniquejobs:abcde2:RUN
        uniquejobs:abcde3:RUN
        uniquejobs:abcde4:RUN
        uniquejobs:abcde5:RUN
        uniquejobs:abcde6:RUN
        uniquejobs:abcde7:RUN
        uniquejobs:abcde8:RUN
        uniquejobs:abcde9:RUN
      ]
    end
  end

  describe ".all" do
    subject(:all) { described_class.all(pattern: "*", count: 1000) }

    include_context "with a regular job"

    it { is_expected.to match_array(expected_keys) }
  end

  describe ".del" do
    subject(:del) { described_class.del(digest: digest, pattern: pattern, count: count) }

    let(:digest)  { nil }
    let(:pattern) { nil }
    let(:count)   { 1000 }

    include_context "with a regular job"

    before do
      allow(described_class).to receive(:log_info)
    end

    context "when given a pattern" do
      let(:pattern) { "*" }

      it "deletes all matching digests" do
        expect(del).to eq(10)
        expect(described_class.all).to match_array([])
      end

      it "logs performance info" do
        del
        expect(described_class)
          .to have_received(:log_info).with(
            a_string_starting_with("delete_by_pattern(*, count: 1000)")
            .and(matching(/completed in (\d\.\d+)ms/)),
          )
      end
    end

    context "when given a digest" do
      let(:digest) { expected_keys.last }

      it "deletes just the specific digest" do
        expect(del).to eq(9)
        expect(described_class.all).to match_array(expected_keys - [digest])
      end

      it "logs performance info" do
        del
        expect(described_class).to have_received(:log_info)
          .with(
            a_string_starting_with("delete_by_digest(#{digest})")
            .and(matching(/completed in (\d\.\d+)ms/)),
          )
      end
    end
  end

  describe ".delete_by_digest" do
    subject(:delete_by_digest) { described_class.delete_by_digest(digest) }

    context "when with a regular job" do
      include_context "with a regular job"

      let(:digest) { expected_keys.last }

      before do
        allow(described_class).to receive(:log_info)
      end

      it "deletes just the specific digest" do
        expect(delete_by_digest).to eq(9)
        expect(described_class.all).to match_array(expected_keys - [digest])
      end

      it "logs performance info" do
        delete_by_digest
        expect(described_class).to have_received(:log_info)
          .with(
            a_string_starting_with("delete_by_digest(#{digest})")
            .and(matching(/completed in (\d\.\d+)ms/)),
          )
      end
    end

    context "when given a runtime job" do
      include_context "with a runtime job"

      let(:digest) { expected_keys.last }

      it "deletes just the specific digest" do
        expect(delete_by_digest).to eq(9)
        expect(unique_keys).not_to include(%W[
                                             #{digest}
                                             #{digest}:EXISTS
                                             #{digest}:GRABBED
                                           ])

        expect(described_class.all).to match_array(expected_keys - [digest])
      end
    end
  end

  describe ".delete_by_pattern" do
    subject(:delete_by_pattern) { described_class.delete_by_pattern(pattern, count: count) }

    let(:pattern) { "*" }
    let(:count)   { 1000 }

    include_context "with a regular job"

    before do
      allow(described_class).to receive(:log_info)
    end

    it "deletes all matching digests" do
      expect(delete_by_pattern).to eq(10)
      expect(described_class.all).to match_array([])
    end

    it "logs performance info" do
      delete_by_pattern
      expect(described_class)
        .to have_received(:log_info).with(
          a_string_starting_with("delete_by_pattern(*, count: 1000)")
          .and(matching(/completed in (\d\.\d+)ms/)),
        )
    end
  end
end
