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
    render json: products
  end

  def products_by_category
    @products = Product.where(category: params[:category])
                                .page(params[:page])
                                .per(params[:per_page])
    render json: @products
  end

  def search
    @products = Product.where("name ILIKE ?", "%#{params[:query]}%")
                                .page(params[:page])
                                .per(params[:per_page])
    render json: @products
  end

  # GET /products/1
  def show
    render json: @product
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
      params.require(:product).permit(:name, :description, :price, :category, :quantity, :user_id)
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
