class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  validates :firstname, :lastname, :date_of_birth, presence: true
  validates :situation, inclusion: { in: %w[student working family] }

  has_many :chats, dependent: :destroy
  has_many :researches, dependent: :destroy

  # Active Storage : permet d'attacher un fichier "avatar" à l'utilisateur.
  # Les fichiers sont stockés séparément de la base (local en dev, S3 possible en prod).
  has_one_attached :avatar

  # validate (sans s) appelle une méthode d'instance personnalisée.
  # On l'utilise ici car content_type: et size: ne sont pas des options natives de Rails —
  # elles appartiennent à la gem active_storage_validations (non installée).
  validate :avatar_format_acceptable, if: -> { avatar.attached? }

  private

  AVATAR_CONTENT_TYPES = %w[image/jpeg image/png image/webp image/gif].freeze
  AVATAR_MAX_SIZE      = 5.megabytes

  def avatar_format_acceptable
    unless AVATAR_CONTENT_TYPES.include?(avatar.blob.content_type)
      errors.add(:avatar, "doit être une image (JPG, PNG, WEBP ou GIF)")
    end

    if avatar.blob.byte_size > AVATAR_MAX_SIZE
      errors.add(:avatar, "ne doit pas dépasser 5 Mo")
    end
  end
end
