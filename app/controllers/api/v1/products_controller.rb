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
    user = User.find_by(store_name: params[:store_name])
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

  # POST /products
  # def create
  #   tags = params[:tags].split(",").map(&:strip).uniq
  #   # Generate a unique product number
  #   product_number = generate_product_number
  
  #   # Create the product with the parsed tags and the generated product number
  #   @product = Product.new(product_params.merge(tags: tags, product_number: product_number))
  
  #   if @product.save
  #     render json: @product, status: :created
  #   else
  #     render json: @product.errors, status: :unprocessable_entity
  #   end
  # end

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

  # PATCH/PUT /products/1
  # def update
  #   if @product.update(product_params)
  #     render json: @product
  #   else
  #     render json: @product.errors, status: :unprocessable_entity
  #   end
  # end

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

    # Only allow a list of trusted parameters through.
    def product_params
      params.permit(:name, :description, :price, :category, :quantity, :user_id, :sold_by, :contact_number, :pictureOne, :pictureTwo, :pictureThree, :pictureFour, :product_number, tags: [])
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
