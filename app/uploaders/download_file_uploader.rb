class DownloadFileUploader < CarrierWave::Uploader::Base
  include Cloudinary::CarrierWave

  # Allow common digital product file types
  def extension_whitelist
    %w[jpg jpeg gif png pdf zip mp3 mp4 txt doc docx xlsx]
  end
end
