require_relative 'application_record'
require_relative 'grunt'

class ContributionApprovalRequest < ApplicationRecord

  attr_accessor :id

  def initialize(id:, time_in_hours:, beneficiary:, approvers:)
    @id = id
    @time_in_hours = time_in_hours.to_f
    @beneficiary = beneficiary

    @approved = {}
    approvers.each do |approver|
      @approved[approver] = nil
    end
  end

  # the slices of pie to be awarded if it is approved
  # probably need guard to see if they are part of the approvers list
  def slices_of_pie
    @beneficiary.hourly_rate * @time_in_hours
  end

  def approved?
    @approved.all? do |k, v|
      v == true
    end
  end

  def voted_by?(voter)
    @approved[voter] != nil
  end

  def approve(from:)
    return false if @approved[from] != nil

    @approved[from] = true

    if approved?
      @beneficiary.contribute(time_in_hours: @time_in_hours)
    end

    return true
  end

  def rejected?
    @approved.any? do |k, v|
      v == false
    end
  end

  def reject(from:)
    return false if @approved[from] != nil

    @approved[from] = false

    return true
  end

  def requested_changes
    msg = ""

    @approved.each do |aGrunt, _|
      if @beneficiary == aGrunt
        msg += "> <@#{aGrunt.name}>: #{aGrunt.slices_of_pie} + #{@time_in_hours * aGrunt.hourly_rate} = #{aGrunt.slices_of_pie + (@time_in_hours * aGrunt.hourly_rate)} :pie:\n"
      else
        msg += "> <@#{aGrunt.name}>: #{aGrunt.slices_of_pie} :pie:\n"
      end
    end

    return msg
  end
end
