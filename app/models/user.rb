class User < ApplicationRecord
    has_secure_password
    
    mount_uploader :avatar, AvatarUploader
    has_many :products, dependent: :destroy
<<<<<<< HEAD
    has_many :sales, dependent: :destroy
=======
    
>>>>>>> 5f39edc0114fca8aa6de2aff3d76971708c304ab
    validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
    validates :password, presence: true, length: { minimum: 8 }, on: :create
    validates :store_name, uniqueness: true, allow_nil: true
    validates :mobile, uniqueness: true, allow_nil: true
<<<<<<< HEAD
    has_one :wallet, dependent: :destroy
    after_commit :create_wallet_if_missing, on: :create
    before_create :set_uuid
    has_many :withdrawals, dependent: :destroy

    def to_param
      uuid
    end
=======
>>>>>>> 5f39edc0114fca8aa6de2aff3d76971708c304ab
    
    def generate_reset_token!
        self.reset_token = SecureRandom.urlsafe_base64
        self.reset_token_expires_at = 1.day.from_now
<<<<<<< HEAD
    end
=======
      end
>>>>>>> 5f39edc0114fca8aa6de2aff3d76971708c304ab
    
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
<<<<<<< HEAD


      private 
      def create_wallet_if_missing
        create_wallet(balance: 0) unless wallet.present?
      end

      def set_uuid
        self.uuid ||= SecureRandom.uuid
      end
=======
>>>>>>> 5f39edc0114fca8aa6de2aff3d76971708c304ab
end
