require 'rails_helper'

RSpec.describe Vote, type: :model do
  it { should belong_to :grunt }
  it { should belong_to :contribution_approval_request }

  describe '#status' do
    it 'defaults to pending' do
      expect(subject.pending?).to be true
    end

    it 'can be set to approved' do
      subject.status = :approved

      expect(subject.approved?).to be true
    end

    it 'can be set to rejected' do
      subject.status = :rejected

      expect(subject.rejected?).to be true
    end
  end

  describe 'already_voted?' do
    it 'is true if approved or rejected' do
      approved = Vote.new(status: :approved)
      rejected = Vote.new(status: :rejected)

      expect(approved.already_voted?).to be true
      expect(rejected.already_voted?).to be true
    end

    it 'is false if pending' do
      pending = Vote.new(status: :pending)

      expect(pending.already_voted?).to be false
    end
  end
end
