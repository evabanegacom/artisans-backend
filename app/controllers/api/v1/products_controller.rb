class Api::V1::ProductsController < ApplicationController
  require 'securerandom'
  before_action :set_product, only: %i[ show update destroy send_download_link ]

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

  # def send_download_link
  #   product = @product
  #   recipient_email = params[:email]
  #   recipient_name = params[:name]
  
  #   unless recipient_email.present? && recipient_name.present?
  #     return render json: { error: "Name and email are required" }, status: 400
  #   end
  
  #   # Generate JWT token
  #   token = JWT.encode(
  #     {
  #       product_id: product.id,
  #       exp: 7.days.from_now.to_i
  #     },
  #     Rails.application.secret_key_base,
  #     "HS256"
  #   )
  
  #   download_url = "#{request.base_url}/api/v1/products/#{product.id}/download?token=#{token}"
  #   expires_at = 7.days.from_now.iso8601

  #   sale = Sale.create!(
  #     product: product,
  #     user: product.user,  # seller
  #     buyer_name: recipient_name,
  #     buyer_email: recipient_email,
  #     amount: product.price,  # Assuming price is the purchase amount
  #     currency: "USD",  # Make dynamic if needed (e.g., params[:currency])
  #     status: "pending",  # Starts as pending, update to completed on download
  #     token_used: token  # Store token for later verification
  #   )
  
  #   begin
  #     send_mailjet_email(recipient_email, recipient_name, product.name, download_url)
      
  #     render json: {
  #       success: true,
  #       order: {
  #         download_url: download_url,
  #         expires_at: expires_at
  #       }
  #     }
  #   rescue => e
  #     render json: { success: false, error: "Failed to send email: #{e.message}" }, status: 500
  #   end
  # end


  def send_download_link
    product = @product  # from before_action :set_product
    recipient_email = params[:email]&.strip
    recipient_name  = params[:name]&.strip
  
    unless recipient_email.present? && recipient_name.present?
      return render json: { error: "Name and email are required" }, status: :bad_request
    end
  
    # Generate secure download token
    token = JWT.encode(
      { product_id: product.id, exp: 7.days.from_now.to_i },
      Rails.application.secret_key_base,
      "HS256"
    )
  
    download_url = "#{request.base_url}/api/v1/products/#{product.id}/download?token=#{token}"
    expires_at   = 7.days.from_now.iso8601
  
    # Create sale record
    sale = Sale.create!(
      product: product,
      user: product.user,           # seller (User who owns the product)
      buyer_name: recipient_name,
      buyer_email: recipient_email,
      amount: product.price,
      currency: "NGN",
      status: "pending",
      token_used: token,
      seller: product.sold_by  # store name or fallback
    )
  
    begin
      # Send download link to buyer
      send_mailjet_email(recipient_email, recipient_name, product.name, download_url)

      # Send notification to seller (only if buyer email succeeded)
      send_seller_email(
        product.user.email,
        product.sold_by || product.user.name || "Seller",
        product.name,
        recipient_name,
        recipient_email,
        product.price,
        sale.id
      )
  
      render json: {
        success: true,
        message: "Download link sent successfully",
        order: {
          download_url: download_url,
          expires_at:   expires_at,
          sale_id:      sale.id
        }
      }, status: :created
  
    rescue => e
      # If anything fails (email, etc.), delete the sale to avoid ghost records
      sale.destroy if sale.persisted?
  
      Rails.logger.error "Sale notification failed: #{e.message}"
  
      render json: {
        success: false,
        error: "Failed to process purchase. Please try again."
      }, status: :unprocessable_entity
    end
  end
  

  # def download
  #   token = params[:token]
  
  #   begin
  #     decoded = JWT.decode(token, Rails.application.secret_key_base, true, algorithm: "HS256")
  #     product_id = decoded[0]["product_id"]
  #   rescue JWT::ExpiredSignature
  #     return render json: { error: "Download link expired" }, status: 401
  #   rescue
  #     return render json: { error: "Invalid token" }, status: 401
  #   end
  
  #   product = Product.find(product_id)
  
  #   if product.download_file.present?
  #     # Generate a signed Cloudinary URL valid for 7 days
  #     download_url = product.download_file.url(expire: 7.days.to_i, attachment: true)
  #     redirect_to download_url, allow_other_host: true
  #   else
  #     render json: { error: "No downloadable file for this product" }, status: 404
  #   end
  # end


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
  
    # Find the associated sale by token
    sale = Sale.find_by(token_used: token)
    if sale.blank?
      return render json: { error: "No sale associated with this token" }, status: 401
    end
  
    # Prevent multiple downloads (optional: allow multiple if needed)
    if sale.status == "completed"
      return render json: { error: "This download link has already been used" }, status: 410
    end
  
    if product.download_file.present?
      # Update sale to completed
      sale.update!(
        status: "completed",
        downloaded_at: Time.current
      )
  
      # Optional: Increment product sales count
      product.increment!(:sales_count) if product.respond_to?(:sales_count)
  
      # Generate signed Cloudinary URL valid for 7 days
      download_url = product.download_file.url(expire: 7.days.to_i, attachment: true)
      redirect_to download_url, allow_other_host: true
    else
      render json: { error: "No downloadable file for this product" }, status: 404
    end
  end
  

  def sales_by_seller
    seller_id = params[:user_id].to_s
    page      = params[:page] || 1
    per_page  = 10
  
    # Load full product associations so CarrierWave works
    sales_page = Sale.joins(:product)
                     .where(products: { user_id: seller_id })
                     .order(created_at: :desc)
                     .paginate(page: page, per_page: per_page)
  
    total_sales = Sale.joins(:product).where(products: { user_id: seller_id }).count
  
    formatted_sales = sales_page.map do |sale|
      {
        id:               sale.id,
        sale_id:          "##{sale.id}",
        status:           sale.status.titleize,
        downloaded_at:    sale.downloaded_at&.strftime("%b %d, %Y %l:%M %p"),
        created_at:       sale.created_at.strftime("%b %d, %Y"),
  
        buyer_name:       sale.buyer_name,
        buyer_email:      sale.buyer_email,
  
        product_name:     sale.product.name,
        product_image:    sale.product.pictureOne.url || "https://via.placeholder.com/150",
        product_category: sale.product.category,
        store_name:       sale.product.sold_by.presence || "Artisan Store",
  
        amount:           sale.amount,
        currency:         sale.currency,
        amount_formatted: ActionController::Base.helpers.number_to_currency(
                            sale.amount,
                            unit: "₦",
                            precision: 0
                          )
      }
    end
  
    render json: {
      sales: formatted_sales,
      pagination: {
        current_page: sales_page.current_page,
        total_pages:  sales_page.total_pages,
        total_sales:  total_sales,
        per_page:     per_page,
        has_next:     sales_page.next_page.present?,
        has_prev:     sales_page.previous_page.present?
      },
      summary: {
        total_revenue: ActionController::Base.helpers.number_to_currency(
                         Sale.joins(:product)
                             .where(products: { user_id: seller_id }, status: "completed")
                             .sum(:amount),
                         unit: "₦", precision: 0
                       ),
        total_orders:     total_sales,
        completed_orders: Sale.joins(:product).where(products: { user_id: seller_id }, status: "completed").count,
        pending_orders:   Sale.joins(:product).where(products: { user_id: seller_id }, status: "pending").count
      }
    }, status: :ok
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
        config.api_key = ENV['APP_MAILJET_API_KEY'] || 'd531ec7b0745a031ceae938c4730e889'
        config.secret_key = ENV['APP_MAILJET_SECRET_KEY'] || '0ca4ac8ba4e43cf761f3a9bc07df7a45'
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


    def send_seller_email(seller_email, seller_name, product_name, buyer_name, buyer_email, amount = nil, sale_id = nil)
      Mailjet.configure do |config|
        config.api_key      = ENV['APP_MAILJET_API_KEY']
        config.secret_key   = ENV['APP_MAILJET_SECRET_KEY']
        config.api_version  = 'v3.1'
      end
    
      amount_formatted = amount ? ActionController::Base.helpers.number_to_currency(amount) : 'N/A'
      sale_ref         = sale_id || '–'
      sale_date        = Time.current.strftime("%B %d, %Y at %I:%M %p")
    
      text_part = <<~TEXT
        Hi #{seller_name},
    
        Great news — your product has been purchased!
    
        Product: #{product_name}
        Buyer: #{buyer_name} (#{buyer_email})
        #{"Amount: #{amount_formatted}" if amount}
        Sale ID: ##{sale_ref}
        Date: #{sale_date}
    
        You can view all your sales in your seller dashboard.
    
        Keep creating amazing products!
    
        — The Artisans Hub Team
      TEXT
    
      html_part = <<~HTML
        <h3 style="color:#2e6c80;">Congratulations, #{seller_name}!</h3>
        <p>You just made a sale!</p>
    
        <table style="width:100%; max-width:600px; font-family:Arial,sans-serif; border-collapse:collapse;">
          <tr>
            <td style="padding:10px; background:#f4f4f4; font-weight:bold;">Product</td>
            <td style="padding:10px;">#{product_name}</td>
          </tr>
          <tr>
            <td style="padding:10px; background:#f4f4f4; font-weight:bold;">Buyer</td>
            <td style="padding:10px;">#{buyer_name} (#{buyer_email})</td>
          </tr>
          #{if amount
            "<tr>
               <td style=\"padding:10px; background:#f4f4f4; font-weight:bold;\">Amount</td>
               <td style=\"padding:10px; font-weight:bold; color:#27ae60;\">#{amount_formatted}</td>
             </tr>"
            end}
          <tr>
            <td style="padding:10px; background:#f4f4f4; font-weight:bold;">Sale ID</td>
            <td style="padding:10px;">##{sale_ref}</td>
          </tr>
          <tr>
            <td style="padding:10px; background:#f4f4f4; font-weight:bold;">Date</td>
            <td style="padding:10px;">#{sale_date}</td>
          </tr>
        </table>
    
        <p style="margin-top:30px;">
          <a href="https://yourdomain.com/seller/dashboard" 
             style="background:#27ae60; color:white; padding:12px 24px; text-decoration:none; border-radius:5px;">
            View All Sales
          </a>
        </p>
    
        <p>Thank you for being part of Artisans Hub!</p>
        <p>— The Team</p>
      HTML
    
      Mailjet::Send.create(messages: [{
        'From' => { 'Email' => 'udegbue69@gmail.com', 'Name' => 'Artisans Hub' },
        'To'   => [{ 'Email' => seller_email, 'Name' => seller_name }],
        'Subject' => "New Sale! #{product_name} just sold",
        'TextPart' => text_part.strip,
        'HTMLPart' => html_part.strip
      }])
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
