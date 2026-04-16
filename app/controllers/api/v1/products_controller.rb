class Api::V1::ProductsController < ApplicationController
  require 'securerandom'
  require 'cgi'

  skip_before_action :credit_available_payouts

  before_action :set_product, only: %i[show update destroy send_download_link]

  # ===================== PUBLIC PRODUCT LISTINGS =====================

  def index
    @products = Product.all.order(created_at: :desc).paginate(page: params[:page], per_page: 20)
    render json: @products.map { |product| safe_product_json(product) }
  end

  def user_products
    products = Product.where(user_id: params[:user_id])
                      .order(created_at: :desc)
                      .paginate(page: params[:page], per_page: 20)

    total_products = Product.where(user_id: params[:user_id]).count

    render json: {
      products: products.map { |p| safe_product_json(p, seller_view: true) },
      total_products: total_products
    }
  end

  def products_by_storename
    user = User.find_by(store_name: params[:store_name]&.strip)
    products = Product.where(sold_by: params[:store_name])
                      .order(created_at: :desc)
                      .paginate(page: params[:page], per_page: 20)

    render json: {
      products: products.map { |p| safe_product_json(p) },
      total_products: products.count,
      store_name: user&.store_name
    }
  end

  def products_by_category
    @products = Product.where('LOWER(category) = ?', params[:category].downcase)
                       .order(created_at: :desc)
                       .paginate(page: params[:page], per_page: 1)

    render json: {
      products: @products.map { |p| safe_product_json(p) },
      total_products: @products.count
    }
  end

  def search
    query = "%#{params[:query].strip.downcase}%"
    trimmed_query = params[:query].strip.downcase

    @products = Product.where(
      "lower(name) ILIKE ? OR lower(description) ILIKE ? OR ? = ANY(tags)",
      query, query, trimmed_query
    ).order(created_at: :desc).paginate(page: params[:page], per_page: 20)

    render json: {
      products: @products.map { |p| safe_product_json(p) },
      total_products: @products.count
    }
  end

  # ===================== SINGLE PRODUCT =====================

  def show
    render json: safe_product_json(@product, include_images: true)
  end

  def get_product_by_product_number
    product = Product.find_by(product_number: params[:product_number])
    return render json: { error: "Product not found" }, status: :not_found unless product

    render json: safe_product_json(product, include_images: true)
  end

  def get_picture_to_edit
    product = Product.find_by(product_number: params[:product_number])
    return render json: { error: "Product not found" }, status: :not_found unless product

    render json: safe_product_json(product, seller_view: true, include_images: true)
  end

  # ===================== CREATE & UPDATE =====================

  def create
    if params[:tags].blank?
      return render json: { error: "Tags are required for product creation" }, status: :unprocessable_entity
    end

    tags = params[:tags].split(",").map(&:strip).uniq
    product_number = generate_product_number

    @product = Product.new(product_params.merge(tags: tags, product_number: product_number))

    if @product.save
      render json: safe_product_json(@product, seller_view: true, include_images: true), status: :created
    else
      render json: @product.errors, status: :unprocessable_entity
    end
  end

  def update
    if params[:tags].present?
      params[:tags] = params[:tags].split(",").map(&:strip).uniq
    end

    if @product.update(product_params)
      render json: safe_product_json(@product, seller_view: true, include_images: true)
    else
      render json: @product.errors, status: :unprocessable_entity
    end
  end

  # ===================== PURCHASE & DOWNLOAD =====================

  def send_download_link
    recipient_email = params[:email]&.strip
    recipient_name  = params[:name]&.strip

    unless recipient_email.present? && recipient_name.present?
      return render json: { error: "Name and email are required" }, status: :bad_request
    end

    token = JWT.encode(
      { product_id: @product.id, exp: 7.days.from_now.to_i },
      Rails.application.secret_key_base,
      "HS256"
    )

    download_url = "#{request.base_url}/api/v1/products/#{@product.id}/download?token=#{token}"
    expires_at   = 7.days.from_now.iso8601

    sale = Sale.create!(
      product: @product,
      user: @product.user,
      buyer_name: recipient_name,
      buyer_email: recipient_email,
      amount: @product.price,
      currency: "NGN",
      status: "pending",
      token_used: token,
      seller: @product.sold_by
    )

    begin
      send_mailjet_email(recipient_email, recipient_name, @product.name, download_url)

      send_seller_email(
        @product.user.email,
        @product.sold_by || @product.user.name || "Seller",
        @product.name,
        recipient_name,
        recipient_email,
        @product.price,
        sale.id
      )

      render json: {
        success: true,
        message: "Download link sent successfully",
        order: {
          download_url: download_url,
          expires_at: expires_at,
          sale_id: sale.id
        }
      }, status: :created

    rescue => e
      sale.destroy if sale.persisted?
      Rails.logger.error "Sale notification failed: #{e.message}"
      render json: { success: false, error: "Failed to process purchase. Please try again." }, status: :unprocessable_entity
    end
  end

  def download
    # Your existing download method (unchanged)
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
    sale = Sale.find_by(token_used: token)

    if sale.blank?
      return render json: { error: "No sale associated with this token" }, status: 401
    end

    if product.download_file.present?
      sale.update!(status: "completed", downloaded_at: Time.current, payable_at: 24.hours.from_now)
      product.increment!(:sales_count) if product.respond_to?(:sales_count)

      download_url = product.download_file.url(expire: 7.days.to_i, attachment: true)
      redirect_to download_url, allow_other_host: true
    else
      render json: { error: "No downloadable file for this product" }, status: 404
    end
  end

  def sales_by_seller
    # Your existing sales_by_seller code (unchanged - kept as is)
    seller_id = params[:user_id].to_s
    page      = params[:page] || 1
    per_page  = 10

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
        amount_formatted: ActionController::Base.helpers.number_to_currency(sale.amount, unit: "₦", precision: 0)
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
          Sale.joins(:product).where(products: { user_id: seller_id }, status: "completed").sum(:amount),
          unit: "₦", precision: 0
        ),
        total_orders:     total_sales,
        completed_orders: Sale.joins(:product).where(products: { user_id: seller_id }, status: "completed").count,
        pending_orders:   Sale.joins(:product).where(products: { user_id: seller_id }, status: "pending").count
      }
    }, status: :ok
  end

  def destroy
    @product.destroy
  end

  # ===================== PRIVATE HELPERS =====================

  private

  def safe_product_json(product, seller_view: false, include_images: false)
    json = {
      id:               product.id,
      name:             product.name,
      description:      product.description,
      price:            product.price,
      category:         product.category,
      quantity:         product.quantity,
      user_id:          product.user_id,
      sold_by:          product.sold_by,
      contact_number:   product.contact_number,
      product_number:   product.product_number,
      tags:             product.tags,
      created_at:       product.created_at,
      updated_at:       product.updated_at,
      uuid:             product.uuid
    }

    # Add images
    if include_images || !product.pictureOne.url.nil?
      json[:image_urls] = [
        product.pictureOne.url,
        product.pictureTwo.url,
        product.pictureThree.url,
        product.pictureFour.url
      ].compact
    end

    # Add individual picture fields (most frontends expect these)
    json[:pictureOne]  = { url: product.pictureOne.url }  if product.pictureOne.url.present?
    json[:pictureTwo]  = { url: product.pictureTwo.url }  if product.pictureTwo.url.present?
    json[:pictureThree] = { url: product.pictureThree.url } if product.pictureThree.url.present?
    json[:pictureFour] = { url: product.pictureFour.url } if product.pictureFour.url.present?

    # Only show download_file to the seller
    if seller_view || (defined?(current_user) && current_user&.id == product.user_id)
      json[:download_file] = { url: product.download_file.url } if product.download_file.present?
    end

    json
  end

  def set_product
    @product = Product.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Product not found" }, status: :not_found
  end

  def generate_product_number
    charset = [('a'..'z'), ('A'..'Z'), (0..9)].map(&:to_a).flatten
    loop do
      product_number = (0...11).map { charset[rand(charset.length)] }.join
      return product_number unless Product.exists?(product_number: product_number)
    end
  end

  # ===================== EMAIL METHODS (unchanged) =====================
  def send_mailjet_email(email, name, product_name, download_url)
    Mailjet.configure do |config|
      config.api_key = ENV['APP_MAILJET_API_KEY']
      config.secret_key = ENV['APP_MAILJET_SECRET_KEY']
      config.api_version = 'v3.1'
    end

    Mailjet::Send.create(messages: [
      {
        'From' => { 'Email' => 'support@artisanshub.net', 'Name' => 'Artisans Hub' },
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

    amount_formatted = amount ? ActionController::Base.helpers.number_to_currency(amount, unit: "₦", separator: ".", delimiter: ",", precision: 2) : 'N/A'
    sale_ref = sale_id || '–'
    sale_date = Time.current.strftime("%B %d, %Y at %I:%M %p")
    store_url = "https://artisanshub.net/#{CGI.escape(seller_name.to_s.strip)}/sales"

    text_part = <<~TEXT
      Hi #{seller_name},

      Great news — your product has been purchased!

      Product: #{product_name}
      Buyer: #{buyer_name} (#{buyer_email})
      Amount: #{amount_formatted}
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
        <tr><td style="padding:10px; background:#f4f4f4; font-weight:bold;">Product</td><td style="padding:10px;">#{product_name}</td></tr>
        <tr><td style="padding:10px; background:#f4f4f4; font-weight:bold;">Buyer</td><td style="padding:10px;">#{buyer_name} (#{buyer_email})</td></tr>
        <tr><td style="padding:10px; background:#f4f4f4; font-weight:bold;">Amount</td><td style="padding:10px; font-weight:bold; color:#27ae60;">#{amount_formatted}</td></tr>
        <tr><td style="padding:10px; background:#f4f4f4; font-weight:bold;">Sale ID</td><td style="padding:10px;">##{sale_ref}</td></tr>
        <tr><td style="padding:10px; background:#f4f4f4; font-weight:bold;">Date</td><td style="padding:10px;">#{sale_date}</td></tr>
      </table>

      <p style="margin-top:30px;">
        <a href="#{store_url}" style="background:#27ae60; color:white; padding:12px 24px; text-decoration:none; border-radius:5px;">
          View All Sales
        </a>
      </p>

      <p>Thank you for being part of Artisans Hub!</p>
      <p>— The Team</p>
    HTML

    Mailjet::Send.create(messages: [{
      'From' => { 'Email' => 'support@artisanshub.net', 'Name' => 'Artisans Hub' },
      'To'   => [{ 'Email' => seller_email, 'Name' => seller_name }],
      'Subject' => "New Sale! #{product_name} just sold",
      'TextPart' => text_part.strip,
      'HTMLPart' => html_part.strip
    }])
  end

  def product_params
    params.permit(
      :name, :description, :price, :category, :download_file, :quantity,
      :user_id, :sold_by, :contact_number, :pictureOne, :pictureTwo,
      :pictureThree, :pictureFour, :product_number, tags: []
    )
  end
end