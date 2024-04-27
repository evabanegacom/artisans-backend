class Product < ApplicationRecord
  attr_accessor :image_urls
  belongs_to :user
  validates :name, :description, :price, :category, :quantity, presence: true
  validates :price, numericality: { greater_than: 0 }
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :sold_by, presence: true
  validates :contact_number, presence: true
  validates :product_number, presence: true
  mount_uploader :pictureOne, AvatarUploader
  mount_uploader :pictureTwo, AvatarUploader
  mount_uploader :pictureThree, AvatarUploader
  mount_uploader :pictureFour, AvatarUploader
  # Callback to process and set image_urls attribute before saving
  before_save :process_image_urls

  def process_image_urls
    self.image_urls = [pictureOne, pictureTwo, pictureThree, pictureFour].compact.map(&:url)
  end
  # add property sold_by to the product model
  # add a validation to ensure that the sold_by property is present
  

end
