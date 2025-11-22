class AvatarUploader < CarrierWave::Uploader::Base
 
  include Cloudinary::CarrierWave

  def extension_whitelist
    %w[svg jpg jpeg gif png]
  end

end