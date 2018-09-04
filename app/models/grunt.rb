require_relative 'application_record'

class Grunt < ApplicationRecord
  # todo: warning emitted with multiple declares
  NONCASH_MULTIPLIER = 2  # todo: this should probably be defined at the project level

  has_many :contribution_approval_requests,
           foreign_key: :submitter_id

  attribute :slices_of_pie, :integer, default: 0
  attribute :base_salary, :float, default: 100_000.0

  validates :name, :slices_of_pie, :base_salary, presence: true
  validates :slices_of_pie, :base_salary, numericality: true
  validates :name, uniqueness: true

  # warning: should only be used by contribution requests
  def contribute(hours:)
    self.slices_of_pie += (hourly_rate * hours)
  end

  def hourly_rate
    base_salary * NONCASH_MULTIPLIER / 2000.0  # todo: I forgot how this 2000.0 is computed by Moyer?
  end
end
