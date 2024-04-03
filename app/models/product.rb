class Product < ApplicationRecord
  belongs_to :user
  validates :name, :description, :price, :category, :quantity, presence: true
  validates :price, numericality: { greater_than: 0 }
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :category, inclusion: { in: %w[Electronics Fashion Home Beauty Toys Books Sports Other] }
  validates :pictureOne, :pictureTwo, :pictureThree, :pictureFour, presence: true
  mount_uploader :pictureOne, AvatarUploader
  mount_uploader :pictureTwo, AvatarUploader
  mount_uploader :pictureThree, AvatarUploader
  mount_uploader :pictureFour, AvatarUploader
end
