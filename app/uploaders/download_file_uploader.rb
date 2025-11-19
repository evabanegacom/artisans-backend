# app/uploaders/download_file_uploader.rb
class DownloadFileUploader < CarrierWave::Uploader::Base
  include Cloudinary::CarrierWave

  # THIS IS THE KEY LINE — makes PDFs, ZIPs, MP3s, etc. work perfectly

  # Complete whitelist: ALL common images + ALL common digital files
  def extension_whitelist
    %w[
      # Images
      jpg jpeg png gif webp bmp tiff tif svg heic heif avif

      # Documents
      pdf doc docx xls xlsx ppt pptx txt csv rtf odt ods odp

      # Archives
      zip rar 7z tar gz

      # Audio
      mp3 wav aac flac ogg m4a

      # Video
      mp4 mov avi mkv webm mpeg mpg

      # Design / Graphics
      psd ai eps indd sketch fig xd

      # Fonts
      ttf otf woff woff2

      # Executables / Apps (use carefully!)
      exe dmg apk
    ]
  end

  # Clean folder structure in Cloudinary
end