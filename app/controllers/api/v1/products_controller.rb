class Api::V1::ProductsController < ApplicationController
  require 'securerandom'
  before_action :set_product, only: %i[ show update destroy ]

  # GET /products
  def index
    @products = Product.all.order(created_at: :desc).paginate(page: params[:page], per_page: 20)
    render json: @products
  end

  def user_products
    @user_products = Product.where(user_id: params[:user_id])
    products = @user_products.order(created_at: :desc).paginate(page: params[:page], per_page: 20)
    total_products = @user_products.count
    render json: { products: products, total_products: total_products }
  end

  def products_by_storename
    user = User.find_by(store_name: params[:store_name].strip)
    products = Product.where(sold_by: params[:store_name])
    products = products.order(created_at: :desc).paginate(page: params[:page], per_page: 20)
    total_products = products.count
    render json: { products: products, total_products: total_products, store_name: user.store_name }
  end

  def products_by_category
@products = Product.where('LOWER(category) = ?', params[:category].downcase).order(created_at: :desc).paginate(page: params[:page], per_page: 20)
    total_products = @products.count
    render json: { products: @products, total_products: total_products }
  end

  def search
    # query = "%#{params[:query].downcase}%"
    query = "%#{params[:query].strip.downcase}%"

    trimmed_query = params[:query].strip.downcase  # Trim leading and trailing whitespace
  
    # Use the ANY operator to check if the tags array contains the search term
    @products = Product.where("lower(name) ILIKE ? OR lower(description) ILIKE ? OR ? = ANY(tags)", query, query, trimmed_query).order(created_at: :desc).paginate(page: params[:page], per_page: 20)
    total_products = @products.count
    render json: { products: @products, total_products: total_products }
  end
  
  # GET /products/1
  def show
    image_urls = [
      @product.pictureOne.url,
      @product.pictureTwo.url,
      @product.pictureThree.url,
      @product.pictureFour.url
    ].compact

    # Merge the image_urls array with the product attributes
    product_with_image_urls = @product.attributes.merge('image_urls' => image_urls)

    # Render JSON response with the product including image URLs
    render json: product_with_image_urls
  end

  def get_product_by_product_number
    product = Product.find_by(product_number: params[:product_number])
    image_urls = [
      product.pictureOne.url,
      product.pictureTwo.url,
      product.pictureThree.url,
      product.pictureFour.url
    ].compact

    # Merge the image_urls array with the product attributes
    product_with_image_urls = product.attributes.merge('image_urls' => image_urls)

    # Render JSON response with the product including image URLs
    render json: product_with_image_urls
  end

  def get_picture_to_edit 
    product = Product.find_by(product_number: params[:product_number])
    render json: product
  end


  def create
    if params[:tags].present? && !params[:tags].empty?
      tags = params[:tags].split(",").map(&:strip).uniq
      # Generate a unique product number
      product_number = generate_product_number
  
      # Create the product with the parsed tags and the generated product number
      @product = Product.new(product_params.merge(tags: tags, product_number: product_number))
  
      if @product.save
        render json: @product, status: :created
      else
        render json: @product.errors, status: :unprocessable_entity
      end
    else
      render json: { error: "Tags are required for product creation" }, status: :unprocessable_entity
    end
  end  
  
  def create_user_wishlist
    wish_list = []
    user = User.find(params[:user_id])
    product = Product.find(params[:product_id])
    wish_list >> product
    user.attributes.merge('wish_list' => wish_list)
  end

  def send_download_link
    product = Product.find(params[:id])
    recipient_email = params[:email]
    recipient_name = params[:name]
  
    unless recipient_email.present? && recipient_name.present?
      return render json: { error: "Name and email are required" }, status: 400
    end
  
    # Generate JWT token
    token = JWT.encode(
      {
        product_id: product.id,
        exp: 7.days.from_now.to_i
      },
      Rails.application.secret_key_base,
      "HS256"
    )
  
    download_url = "#{request.base_url}/api/v1/products/#{product.id}/download?token=#{token}"
    expires_at = 7.days.from_now.iso8601
  
    begin
      send_mailjet_email(recipient_email, recipient_name, product.name, download_url)
      
      render json: {
        success: true,
        order: {
          download_url: download_url,
          expires_at: expires_at
        }
      }
    rescue => e
      render json: { success: false, error: "Failed to send email: #{e.message}" }, status: 500
    end
  end
  

  def download
    token = params[:token]
  
    begin
      decoded = JWT.decode(token, Rails.application.secret_key_base, true, algorithm: "HS256")
      product_id = decoded[0]["product_id"]
    rescue JWT::ExpiredSignature
      return render json: { error: "Download link expired" }, status: 401
    rescue
      return render json: { error: "Invalid token" }, status: 401
    end
  
    product = Product.find(product_id)
  
    if product.download_file.present?
      # Generate a signed Cloudinary URL valid for 7 days
      download_url = product.download_file.url(expire: 7.days.to_i, attachment: true)
      redirect_to download_url, allow_other_host: true
    else
      render json: { error: "No downloadable file for this product" }, status: 404
    end
  end
  

  

  def update
    # Retrieve the existing product tags
    existing_tags = @product.tags
    # Split, strip, and remove duplicates from the new tags
    new_tags = params[:tags].uniq
    # Update the product attributes with the filtered tags
    if @product.update(product_params.merge(tags: new_tags))
      render json: @product
    else
      render json: @product.errors, status: :unprocessable_entity
    end
  end
  

  # DELETE /products/1
  def destroy
    @product.destroy
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_product
      @product = Product.find(params[:id])
    end

    def generate_product_number
      charset = [('a'..'z'), ('A'..'Z'), (0..9)].map(&:to_a).flatten
      product_number = (0...11).map { charset[rand(charset.length)] }.join
      product_number = generate_product_number if Product.exists?(product_number: product_number)
      product_number
    end

    def send_mailjet_email(email, name, product_name, download_url)
      Mailjet.configure do |config|
        config.api_key = ENV['APP_API_KEY']
        config.secret_key = ENV['APP_SECRET_KEY']
        config.api_version = 'v3.1'
      end
  
      Mailjet::Send.create(messages: [
        {
          'From' => { 'Email' => 'udegbue69@gmail.com', 'Name' => 'Artisans Hub' },
          'To' => [{ 'Email' => email, 'Name' => name }],
          'Subject' => "Your Download Link for #{product_name}",
          'TextPart' => "Hi #{name},\n\nHere is your download link for #{product_name}: #{download_url}\n\nNote: This link expires in 7 days.",
          'HTMLPart' => "<p>Hi #{name},</p><p>Here is your download link for <strong>#{product_name}</strong>:</p><p><a href='#{download_url}'>Download Now</a></p><p>Note: This link expires in 7 days.</p>"
        }
      ])
    end

    # Only allow a list of trusted parameters through.
    def product_params
      params.permit(:name, :description, :price, :category, :download_file, :quantity, :user_id, :sold_by, :contact_number, :pictureOne, :pictureTwo, :pictureThree, :pictureFour, :product_number, tags: [])
    end    
end

# {
#   "name": "Product 1",
#   "description": "Product 1 description",
#   "price": 100,
#   "category": "Electronics",
#   "quantity": 10,
#   "user_id": 1
# }
