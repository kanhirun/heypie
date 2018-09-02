class State
  def self.team
    @@team ||= [
      Grunt.new(name: "U1UESB3TP"),  # daiv
      Grunt.new(name: "U1UGEND33"),  # kel
      Grunt.new(name: "UCBMB4W3C"),  # justin
      Grunt.new(name: "UCD1YB1E2"),  # chip
      Grunt.new(name: "UCBRKETRT")   # vu
    ]
  end

  def self.team=(newValue)
    @@team = newValue
  end

  def self.pie_estimated_valuation
    val = @@team.map do |aGrunt|
      aGrunt.slices_of_pie
    end

    return 0 if val == []

    val.inject(&:+) / Grunt::NONCASH_MULTIPLIER
  end

  def self.contribution_approval_request
    @contribution_approval_request ||= nil
  end

  def self.contribution_approval_request=(new_request)
    @contribution_approval_request = new_request
  end
end

