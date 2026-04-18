class Research < ApplicationRecord
  belongs_to :user

  validates :research_name, presence: true, uniqueness: { scope: :user_id }
end
