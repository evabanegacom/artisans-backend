class Api::V1::ProductsController < ApplicationController
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
    products = Product.where(sold_by: params[:store_name])
    products = products.order(created_at: :desc).paginate(page: params[:page], per_page: 20)
    total_products = products.count
    render json: { products: products, total_products: total_products }
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

  # POST /products
  def create
    @product = Product.new(product_params)

    if @product.save
      render json: @product, status: :created
    else
      render json: @product.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /products/1
  def update
    if @product.update(product_params)
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

    # Only allow a list of trusted parameters through.
    def product_params
      params.permit(:name, :description, :price, :category, :quantity, :user_id, :sold_by, :contact_number, :pictureOne, :pictureTwo, :pictureThree, :pictureFour, :product_number, :tags)
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
