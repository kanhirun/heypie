require 'spec_helper'

require_relative '../../app/models/state'
require_relative '../../app/models/grunt'

RSpec.describe State do
  describe '#team' do
    xit 'has a getter' do
      expect(State.team).to eql []
    end

    it 'has a setter' do
      State.team = [1,2,3]

      expect(State.team).to eql [1,2,3]
    end
  end

  describe '#contribution_approval_request' do
    it 'has a getter' do
      expect(State.contribution_approval_request).to eql nil
    end

    it 'has a setter' do
      State.contribution_approval_request = 'some-value'

      expect(State.contribution_approval_request).to eql 'some-value'
    end
  end

  describe 'Pie#estimated_valuation' do
    it 'returns the estimated valuation' do
      State.team = []
      expect(State.pie_estimated_valuation).to eql 0
    end

    it 'returns the estimated valuation' do
      someGrunt = Grunt.new(name: 'some-name', base_salary: 100_000)
      State.team = [someGrunt]

      someGrunt.contribute(time_in_hours: 7.0)

      expected = (100_000 * Grunt::NONCASH_MULTIPLIER / 2000.0) * 7.0 / 2.0

      expect(State.pie_estimated_valuation).to eql expected
    end
  end
end
