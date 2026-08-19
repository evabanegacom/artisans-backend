class AvatarUploader < CarrierWave::Uploader::Base
 
  include Cloudinary::CarrierWave

  def extension_whitelist
<<<<<<< HEAD
    %w[svg jpg jpeg gif png]
=======
    %w[jpg jpeg gif png]
>>>>>>> 5f39edc0114fca8aa6de2aff3d76971708c304ab
  end

end