require_relative 'application_record'

class Grunt < ApplicationRecord

  NONCASH_MULTIPLIER = 2  # todo: this should probably be defined at the project level

  attribute :slices_of_pie, :float, default: 0.0
  attribute :base_salary, :float, default: 100_000

  validates :name, presence: true, uniqueness: true

  def contribute(time_in_hours:)
    self.slices_of_pie += (hourly_rate * time_in_hours)
  end

  def hourly_rate
    base_salary * NONCASH_MULTIPLIER / 2000.0  # todo: I forgot how this 2000.0 is computed by Moyer?
  end
end
