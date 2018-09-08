class Vote < ApplicationRecord
  belongs_to :grunt
  belongs_to :contribution

  enum status: [ "pending", "approved", "rejected" ]

  def already_voted?
    status != "pending"
  end
end
