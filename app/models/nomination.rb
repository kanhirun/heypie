class Nomination < ApplicationRecord
  belongs_to :grunt
  belongs_to :contribution

  validates :slices_of_pie_to_be_rewarded, presence: true, numericality: true
end
