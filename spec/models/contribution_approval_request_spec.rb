require 'rails_helper'

require_relative '../../app/models/contribution_approval_request'

# todo: improve API so that we can represent the rewards
RSpec.describe ContributionApprovalRequest do
  it { should belong_to :submitter }
  it { should validate_presence_of :submitter }
  it { should have_many :nominations }
  it { should have_many :nominated_grunts }
  it { should have_many :votes }
  it { should have_many :voters }

  # todo: move me to a service
  describe 'contribute_hours(dict)' do
    it 'creates nominations internally without persisting' do
      bob   = Grunt.create!(name: "Bob")
      alice = Grunt.create!(name: "Alice")
      subject.submitter = Grunt.new

      expect do
        subject.contribute_hours(bob => 1, alice => 2)
        subject.process

        bob.reload
        alice.reload
      end.to change { bob.slices_of_pie }.by(100)
        .and change { alice.slices_of_pie }.by(200)

      expect(subject.nominated_grunts.to_a).to eql [bob, alice]
      expect(subject.nominations.length).to eql 2
      expect(subject.nominations.first.slices_of_pie_to_be_rewarded).to eql 100
      expect(subject.nominations.last.slices_of_pie_to_be_rewarded).to eql 200
      expect(subject.nominations.map(&:slices_of_pie_to_be_rewarded).inject(:+)).to eql 300
    end
  end

  describe '#status' do
    it 'defaults to pending' do
      some_voters = [Grunt.new, Grunt.new]
      with_voters = ContributionApprovalRequest.new(voters: some_voters)

      expect(with_voters.status).to eql 'pending'
    end

    it 'returns approved if there are no voters' do
      no_voters = ContributionApprovalRequest.new(voters: [])

      expect(no_voters.status).to eql 'approved'
    end

    it 'returns rejected if there is just one rejected vote' do
      g1, g2 = [ Grunt.create!(name: 'g1'), Grunt.create!(name: 'g2') ]
      one_reject = ContributionApprovalRequest.create!(submitter: Grunt.new, voters: [g1, g2])
      one_reject.votes.create! [
        { status: "approved", grunt: g1 },
        { status: "rejected", grunt: g2 }
      ]

      expect(one_reject.status).to eql 'rejected'
    end
  end

  describe '#process' do
    it 'rewards the beneficiaries with slices of pie' do
      beneficiary = Grunt.create!(name: 'some-beneficiary')

      subject = ContributionApprovalRequest.create!(
        submitter: Grunt.new,
        voters: []
      )

      subject.nominations.create!({
        contribution_approval_request: subject,
        grunt: beneficiary,
        slices_of_pie_to_be_rewarded: 100
      })

      expect do
        subject.process
        beneficiary.reload
      end.to change{ beneficiary.slices_of_pie }.from(0.0).to(100.0)
    end

    it 'cannot process more than once' do
      beneficiary = Grunt.create!(name: 'some-beneficiary')
      reward = 100.00

      subject = ContributionApprovalRequest.create!(
        submitter: Grunt.new,
        voters: []
      )

      subject.nominations.create!({
        contribution_approval_request: subject,
        grunt: beneficiary,
        slices_of_pie_to_be_rewarded: reward
      })

      subject.process
      beneficiary.reload

      expect do
        subject.process
        beneficiary.reload
      end.not_to change{ beneficiary.slices_of_pie }
    end

    it 'returns false if voting is incomplete' do
      subject = ContributionApprovalRequest.create!(
        submitter: Grunt.new,
        voters: [ Grunt.create!(name: 'Alice'), Grunt.create!(name: 'Bob') ]
      )

      expect(subject.status).to eql "pending"

      results = subject.process

      expect(results).to be false
    end
  end

  describe '#approve!(from:)' do
    it 'sets a result' do
      subject = ContributionApprovalRequest.create!(submitter: Grunt.new)
      a_voter = subject.voters.create!(name: "a-voter")
      vote = Vote.find_by!(grunt: a_voter)

      subject.approve!(from: a_voter)

      expect do
        vote.reload
      end.to change{ vote.status }.from("pending").to("approved")
    end

    it 'raises an error when a voter is an outsider' do
      outsider = Grunt.new
      nobody = []
      subject = ContributionApprovalRequest.new(voters: nobody)

      expect do
        subject.approve!(from: outsider)
      end.to raise_error(CannotVoteIfYouAreAnOutsiderError)
    end

    it 'raises an error if voter already voted' do
      voter = Grunt.create!(name: 'some-grunt')
      subject = ContributionApprovalRequest.create!(submitter: Grunt.new, voters: [voter])

      expect do
        subject.approve!(from: voter)
        subject.approve!(from: voter)
      end.to raise_error(AlreadyVotedError)
    end
  end

  describe '#reject!(from:)' do
    it 'sets a result' do
      subject = ContributionApprovalRequest.create!(submitter: Grunt.new)
      a_voter = subject.voters.create!(name: "a-voter")
      vote = Vote.find_by!(grunt: a_voter)

      subject.reject!(from: a_voter)

      expect do
        vote.reload
      end.to change{ vote.status }.from("pending").to("rejected")
    end

    it 'raises an error when a voter is an outsider' do
      outsider = Grunt.new
      nobody = []
      subject = ContributionApprovalRequest.new(voters: nobody)

      expect do
        subject.reject!(from: outsider)
      end.to raise_error(CannotVoteIfYouAreAnOutsiderError)
    end

    it 'raises an error if voter already voted' do
      voter = Grunt.create!(name: 'some-grunt')
      subject = ContributionApprovalRequest.create!(submitter: Grunt.new, voters: [voter])
      vote = Vote.find_by!(grunt: voter)

      expect do
        subject.reject!(from: voter)
        subject.approve!(from: voter)
      end.to raise_error(AlreadyVotedError)

      vote.reload

      expect(vote.status).to eql "rejected"
    end
  end

  context 'some approvers' do
    let(:some_approvers) { [Grunt.new, Grunt.new] }

    it 'credits only if 100% approval' do
      # a_beneficiary = Grunt.new
      # subject = ContributionApprovalRequest.new(
      #   nominated_grunts: [a_beneficiary],
      #   voters: some_approvers
      # )

      # # 100% approval
      # some_approvers.each do |voter|
      #   subject.approve!(from: voter)
      # end

      # expect{ subject.run! }.to change {
      #   a_beneficiary.slices_of_pie
      # }
    end

    it 'does not credit if not 100% approval' do
    end
  end

  context 'no approvers' do
  end
end
