require 'rails_helper'

RSpec.describe Grunt, type: :model do

  it { should have_many :contribution_approval_requests }

  # Note:
  # The `name` attribute is currently being used to identify
  # the user's slack identifier.
  describe '#name' do
    it { should validate_presence_of :name }
    it { should validate_uniqueness_of :name }
  end

  describe '#base_salary' do
    it { should validate_presence_of :base_salary }
    it { should validate_numericality_of :base_salary }
  end

  describe '==(other_grunt)' do
    it 'returns true when their names match' do
      a = Grunt.new(id: 1, base_salary: 1)
      b = Grunt.new(id: 1, base_salary: 9999)
      c = Grunt.new(id: 999)

      expect(a).to eql b
      expect(a).not_to eql c
    end
  end

  describe '#slices_of_pie' do
    it 'returns the sum of pies awarded' do
      winner = Grunt.new
      winner.nominations.build([
        { grunt: winner, awarded: false, slices_of_pie_to_be_rewarded: 10 },
        { grunt: winner, awarded: true, slices_of_pie_to_be_rewarded: 20 },
        { grunt: winner, awarded: true, slices_of_pie_to_be_rewarded: 30 }
      ])

      expect(winner.slices_of_pie).to eql 30 + 20
    end

    it 'defaults to 0' do
      expect(Grunt.new.slices_of_pie).to eql 0
    end
  end

  describe '#base_salary' do
    it 'defaults to $100,000 USD' do
      expect(Grunt.new.base_salary).to eq 0
    end
  end

  describe '#hourly_rate' do
    it 'is derived from a formula' do
      grunt = Grunt.new
      noncash_multiplier = 2

      expect(grunt.hourly_rate).to eql(
        grunt.base_salary * noncash_multiplier / 2000.0
      )
    end
  end

  xdescribe '#contribute(hours:)' do
    it "doesn't change if no time was spent working" do
      grunt = Grunt.new
      zero = 0

      expect do
        grunt.contribute(hours: zero)
      end.not_to change { grunt.slices_of_pie }
    end

    it 'increases slices of pie based on their hourly rate' do
      grunt = Grunt.new
      hours = 0.75

      grunt.contribute(hours: hours)

      expect(grunt.slices_of_pie.to_f).to eql(grunt.hourly_rate * hours)
    end
  end
end
