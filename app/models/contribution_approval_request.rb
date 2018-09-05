require_relative 'application_record'
require_relative 'grunt'

class CannotVoteIfYouAreAnOutsiderError < StandardError; end
class AlreadyVotedError < StandardError; end
class NotFinishedVotingError < StandardError; end

class ContributionApprovalRequest < ApplicationRecord

  belongs_to :submitter, class_name: 'Grunt', foreign_key: :submitter_id
  has_many :nominations
  has_many :nominated_grunts, through: :nominations, source: :grunt
  has_many :votes
  has_many :voters, through: :votes, source: :grunt

  attribute :processed, :boolean, default: false

  # an enum - pending, approved, or rejected
  def status
    return "approved" if voters.empty?

    statuses = votes.map(&:status).uniq

    case statuses
    when ["approved"]
      return "approved"
    when ["pending"]
      return "pending"
    else
      return "rejected"
    end
  end

  def process
    return false if status == "pending" || status == "rejected" || processed

    nominations.each do |nomination|
      beneficiary = nomination.grunt
      reward = nomination.slices_of_pie_to_be_rewarded  # todo

      beneficiary.slices_of_pie += reward
      beneficiary.save!
    end

    self.processed = true

    return true
  end

  def approve!(from:)
    vote = get_vote!(from: from)
    vote.status = "approved"
    vote.save!
  end

  def reject!(from:)
    vote = get_vote!(from: from)
    vote.status = "rejected"
    vote.save!
  end

  private
    def get_vote!(from:)
      vote = Vote.find_by(grunt: from, contribution_approval_request: self)

      raise CannotVoteIfYouAreAnOutsiderError.new if voters.exclude?(from)
      raise AlreadyVotedError.new if vote.already_voted?

      vote
    end
end
