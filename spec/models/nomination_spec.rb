require 'rails_helper'

RSpec.describe Nomination, type: :model do
  it { should belong_to :grunt }
  it { should belong_to :contribution }
  it { should validate_presence_of :slices_of_pie_to_be_rewarded }
  it { should validate_numericality_of :slices_of_pie_to_be_rewarded }
end
