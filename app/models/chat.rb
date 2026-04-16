class Chat < ApplicationRecord
  belongs_to :user
  has_many :messages, dependent: :destroy

  validates :title, length: { maximum: 100 }, allow_blank: true
end
