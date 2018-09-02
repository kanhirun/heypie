class Grunt
  attr_reader :base_salary, :hourly_rate, :slices_of_pie, :name

  NONCASH_MULTIPLIER = 2  # todo: this should probably be defined at the project level

  def initialize(name:, base_salary: 100_000.0)
    @name = name
    @base_salary = base_salary
    @hourly_rate = base_salary * NONCASH_MULTIPLIER / 2000.0
    @slices_of_pie = 0
  end

  def contribute(time_in_hours:)
    return if time_in_hours.to_f.zero?

    @slices_of_pie += (@hourly_rate.to_f * time_in_hours.to_f)
  end

  # comparing grunts
  def ==(other)
    @name == other.name
  end
end

