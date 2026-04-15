class Research < ApplicationRecord
  belongs_to :user

  validates :research_name, presence: true, uniqueness: true
end
