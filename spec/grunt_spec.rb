require 'spec_helper'

require_relative '../app/models/grunt'

RSpec.describe Grunt do

  let(:grunt) do
    Grunt.new(name: 'some-name')
  end

  it 'has a name assigned' do
    grunt = Grunt.new(name: 'Alice')

    expect(grunt.name).to eql 'Alice'
  end

  it 'has 0 slices of pie by default' do
    expect(grunt.slices_of_pie).to eq 0
  end

  describe '==(other_grunt)' do
    it 'is equal if names are equal' do
      expect(Grunt.new(name: 'Alice')).to eq Grunt.new(name: 'Alice')
    end
  end

  describe '#base_salary' do
    it 'has a fixed salary of $100,000 USD' do
      expect(grunt.base_salary).to eq 100_000
    end

    it 'has a derived hourly rate based on that salary' do
      expect(grunt.hourly_rate).to eq(100_000 * 2 / 2000.0)
    end
  end

  describe '#contribute(time_in_hours:)' do
    it "doesn't change if no time was spent working" do
      zero = 0

      expect do
        grunt.contribute(time_in_hours: zero)
      end.not_to change { grunt.slices_of_pie }
    end

    it 'increases slices of pie based on their hourly rate' do
      grunt = Grunt.new(name: "some-name")

      grunt.contribute(time_in_hours: 22)

      expect(grunt.slices_of_pie).to eql(grunt.hourly_rate * 22)
    end
  end
end
