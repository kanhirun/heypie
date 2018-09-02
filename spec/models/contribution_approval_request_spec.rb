require 'spec_helper'

require_relative '../../app/models/contribution_approval_request'

RSpec.describe ContributionApprovalRequest do
  it 'takes in a few params' do
    contributor = Grunt.new(name: 'aHappyGrunt')
    approvers = [
      contributor,
      Grunt.new(name: 'otherGrunt'),
      Grunt.new(name: 'anotherGrunt'),
    ]
    time_in_hours = 10

    ContributionApprovalRequest.new(id: 'some-id', approvers: approvers, beneficiary: contributor, time_in_hours: time_in_hours)
  end

  it 'should only allow voters to vote once' do
    contributor = Grunt.new(name: 'aHappyGrunt')
    g1 = Grunt.new(name: 'otherGrunt')
    g2 = Grunt.new(name: 'anotherGrunt')
    approvers = [ contributor, g1, g2 ]
    time_in_hours = 10

    c = ContributionApprovalRequest.new(id: 'some-id', approvers: approvers, beneficiary: contributor, time_in_hours: time_in_hours)

    expect(c.voted_by?(contributor)).to be false
    expect(c.voted_by?(g1)).to be false
    expect(c.voted_by?(g2)).to be false
    c.approve(from: contributor)
    c.approve(from: g1)
    c.approve(from: g2)
    expect(c.voted_by?(contributor)).to be true
    expect(c.voted_by?(g1)).to be true
    expect(c.voted_by?(g2)).to be true

    expect(c.approved?).to be true

    expect(contributor.slices_of_pie).to eql(100_000 * 2 / 2000.0 * time_in_hours)
  end

  it 'returns false if already set before' do
    contributor = Grunt.new(name: 'aHappyGrunt')
    approvers = [
      contributor,
      Grunt.new(name: 'otherGrunt'),
      Grunt.new(name: 'anotherGrunt'),
    ]
    time_in_hours = 10

    c = ContributionApprovalRequest.new(id: 'some-id', approvers: approvers, beneficiary: contributor, time_in_hours: time_in_hours)

    c.approve(from: contributor)
    results = c.approve(from: contributor)

    expect(results).to eql false
  end

  it 'returns true for reject too' do
    contributor = Grunt.new(name: 'aHappyGrunt')
    approvers = [
      contributor,
      Grunt.new(name: 'otherGrunt'),
      Grunt.new(name: 'anotherGrunt'),
    ]
    time_in_hours = 10

    c = ContributionApprovalRequest.new(id: 'some-id', approvers: approvers, beneficiary: contributor, time_in_hours: time_in_hours)

    results = c.reject(from: contributor)

    expect(results).to eql true
  end

  it 'returns false for reject too' do
    contributor = Grunt.new(name: 'aHappyGrunt')
    approvers = [
      contributor,
      Grunt.new(name: 'otherGrunt'),
      Grunt.new(name: 'anotherGrunt'),
    ]
    time_in_hours = 10

    c = ContributionApprovalRequest.new(id: 'some-id', approvers: approvers, beneficiary: contributor, time_in_hours: time_in_hours)

    c.reject(from: contributor)
    results = c.reject(from: contributor)

    expect(results).to eql false
  end

  it 'should only allow voters to vote once' do
    contributor = Grunt.new(name: 'aHappyGrunt')
    approvers = [
      contributor,
      Grunt.new(name: 'otherGrunt'),
      Grunt.new(name: 'anotherGrunt'),
    ]
    time_in_hours = 10

    c = ContributionApprovalRequest.new(id: 'some-id', approvers: approvers, beneficiary: contributor, time_in_hours: time_in_hours)

    expect(c.voted_by?(contributor)).to be false
    c.reject(from: contributor)
    expect(c.voted_by?(contributor)).to be true
  end

  it 'has an id that we can use to send messages (on comment threads) to slack' do
    contributor = Grunt.new(name: 'aHappyGrunt')
    approvers = [
      contributor,
      Grunt.new(name: 'otherGrunt'),
      Grunt.new(name: 'anotherGrunt'),
    ]
    time_in_hours = 10

    ContributionApprovalRequest.new(id: 'some-timestamp', approvers: approvers, beneficiary: contributor, time_in_hours: time_in_hours)
  end

  it '#slices_of_pie' do
    contributor = Grunt.new(name: 'aHappyGrunt')
    approvers = [
      contributor,
      Grunt.new(name: 'otherGrunt'),
      Grunt.new(name: 'anotherGrunt'),
    ]
    time_in_hours = 10

    sut = ContributionApprovalRequest.new(id: 'some-id', approvers: approvers, beneficiary: contributor, time_in_hours: time_in_hours)

    expect(contributor.slices_of_pie).to eql 0
    expect(sut.slices_of_pie).to eql(time_in_hours * contributor.hourly_rate)
    expect(contributor.slices_of_pie).to eql 0
  end

  xit 'errors when the contributor is not part of the approvers list' do
  end

  it '#approved? returns false by default' do
    contributor = Grunt.new(name: 'aHappyGrunt')
    approvers = [
      contributor,
      Grunt.new(name: 'otherGrunt'),
    ]
    time_in_hours = 10

    c = ContributionApprovalRequest.new(id: 'some-id', approvers: approvers, beneficiary: contributor, time_in_hours: time_in_hours)

    expect(c.approved?).to be(false)
  end

  it '#approved? returns true when all approvers are happy' do
    contributor = Grunt.new(name: 'aHappyGrunt')
    approver = Grunt.new(name: 'otherGrunt')
    approvers = [
      contributor,
      approver
    ]
    time_in_hours = 10

    c = ContributionApprovalRequest.new(id: 'some-id', approvers: approvers, beneficiary: contributor, time_in_hours: time_in_hours)

    c.approve(from: approver)
    c.approve(from: contributor)

    expect(c.approved?).to be(true)
  end

  it '#approved? returns true when all approvers are happy' do
    contributor = Grunt.new(name: 'aHappyGrunt')
    approver = Grunt.new(name: 'otherGrunt')
    approver2 = Grunt.new(name: 'yetAnotherGrunt')
    approvers = [
      contributor,
      approver,
      approver2
    ]
    time_in_hours = 10

    c = ContributionApprovalRequest.new(id: 'some-id', approvers: approvers, beneficiary: contributor, time_in_hours: time_in_hours)

    c.approve(from: approver)

    expect(c.approved?).to be(false)
  end

  it '#reject sets the property to false' do
    beneficiary = Grunt.new(name: 'aHappyGrunt')
    voter = Grunt.new(name: 'otherGrunt')
    approvers = [
      beneficiary,
      voter
    ]
    time_in_hours = 10

    c = ContributionApprovalRequest.new(id: 'some-id', approvers: approvers, beneficiary: beneficiary, time_in_hours: time_in_hours)

    expect(c.approved?).to be(false)
    expect(c.rejected?).to be(false)

    c.approve(from: voter)
    c.approve(from: beneficiary)

    expect(c.approved?).to be(true)
    expect(c.rejected?).to be(false)

    c.reject(from: voter)

    expect(c.approved?).to be(true)
    expect(c.rejected?).to be(false)
  end

  it 'if everythign is approved then they get slices of pie' do
    justin = Grunt.new(name: "Justin")
    kel = Grunt.new(name: "Kel")
    approvers = [
      kel,
      justin
    ]
    time_in_hours = 2  # office hours

    c = ContributionApprovalRequest.new(id: 'some-id', approvers: approvers, beneficiary: justin, time_in_hours: time_in_hours)

    expect(justin.slices_of_pie).to eql(0)

    c.approve(from: kel)
    c.approve(from: justin)

    expect(justin.hourly_rate).to eql(100_000.0 * 2 / 2000.0)
    expect(justin.slices_of_pie).to eql(justin.hourly_rate * time_in_hours)
  end
end
