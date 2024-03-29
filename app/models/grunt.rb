require_relative 'application_record'

class Grunt < ApplicationRecord

  # todo: temp
  def self.heypie_grunts
    Grunt.take(5).to_a
  end

  # todo: warning emitted with multiple declares
  NONCASH_MULTIPLIER = 2  # todo: this should probably be defined at the project level

  has_many :nominations

  # todo: rename to submissions or submitted_contributions
  has_many :contributions, foreign_key: :submitter_id

  validates :slack_user_id, presence: true, uniqueness: true
  validates :base_salary,   presence: true, numericality: true

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
