class User < ApplicationRecord
    has_secure_password
    
    mount_uploader :avatar, AvatarUploader
    has_many :products, dependent: :destroy
    
    validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
    validates :password, presence: true, length: { minimum: 8 }, on: :create
    validates :store_name, uniqueness: true
    
    def generate_reset_token!
        self.reset_token = SecureRandom.urlsafe_base64
        self.reset_token_expires_at = 1.day.from_now
      end
    
      def activation_token_expired?
        return false unless activation_token_expires_at.present?
    
        activation_token_expires_at < Time.zone.now
      end
    
      def activation_token_valid?
        activation_token_expires_at.present? && activation_token_expires_at > Time.now
      end
    
      def reset_token_valid?
        reset_token_expires_at.present? && reset_token_expires_at > Time.now
      end
    
      def as_json(options = {})
        super(options.merge({ except: %i[password_digest created_at updated_at] }))
      end
end
