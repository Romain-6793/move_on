class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  validates :firstname, :lastname, :date_of_birth, presence: true
  validates :situation, inclusion: { in: %w[student working family] }

  has_many :chats, dependent: :destroy
  has_many :researches, dependent: :destroy
end
