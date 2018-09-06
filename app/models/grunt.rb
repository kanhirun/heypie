require_relative 'application_record'

class Grunt < ApplicationRecord
  # todo: warning emitted with multiple declares
  NONCASH_MULTIPLIER = 2  # todo: this should probably be defined at the project level

  has_many :nominations

  # todo: rename to submissions or submitted_contributions
  has_many :contribution_approval_requests, foreign_key: :submitter_id

  attribute :base_salary, :float, default: 100_000.0 # todo: hmm... 100K eh

  validates :name,        presence: true, uniqueness: true
  validates :base_salary, presence: true, numericality: true

  def slices_of_pie
    # todo: use scope
    rewards = nominations.select{ |n| n.awarded == true }

    return 0 if rewards.empty?

    nominations.select { |n| n.awarded == true }
               .map(&:slices_of_pie_to_be_rewarded)
               .inject(:+)
  end

  def hourly_rate
    base_salary * NONCASH_MULTIPLIER / 2000.0  # todo: I forgot how this 2000.0 is computed by Moyer?
  end
end
