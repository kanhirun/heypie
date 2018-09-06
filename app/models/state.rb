class State
  def self.pie_estimated_valuation
    val = Grunt.heypie_grunts.map do |aGrunt|
      aGrunt.slices_of_pie
    end

    return 0 if val == []

    val.inject(&:+) / Grunt::NONCASH_MULTIPLIER
  end
end

