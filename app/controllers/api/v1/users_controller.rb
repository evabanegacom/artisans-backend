require 'mailjet'
require 'securerandom'
class Api::V1::UsersController < ApplicationController
  skip_before_action :credit_available_payouts, only: [:create, :sign_in, :generate_activation_token]
  
  before_action :set_user, only: %i[ show update destroy ]

  # GET /users
  def index
    @users = User.all

    render json: @users
  end

  # GET /users/1
  def show
    render json: @user
  end

  # POST /users
  # POST /users
# POST /users
def create
  user = User.new(user_params)
  if user.save
    user.update_columns(
      activation_token: SecureRandom.urlsafe_base64,
      activation_token_expires_at: 2.days.from_now
    )

    # Set current_user globally
    @current_user = user

    jwt_token = generate_jwt_token(user)

    # Define the email template path
    html_template_path = File.expand_path('../../../../views/user_mailer/activation_email.html.erb', __FILE__)

    # Send activation email
    send_activation_email(user, html_template_path)

    render json: { user: user, jwt_token: jwt_token, message: "Validation email sent to your email address" }, status: :created
  else
    render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
  end
end


# POST /sign_in
def sign_in
  user = User.find_by(email: params[:email])
  if user&.authenticate(params[:password])
    @current_user = user # globally available now
    jwt_token = generate_jwt_token(user)
    render json: { user: user, jwt_token: jwt_token, message: "Signed in" }, status: :ok
  else
    render json: { error: "Invalid credentials" }, status: :unauthorized
  end
end
# Generate JWT token for user

def generate_jwt_token(user)
  payload = {
    user_id: user.uuid,          # now using UUID
    jti: SecureRandom.uuid,      # unique token identifier
    exp: 1.day.from_now.to_i     # expiry timestamp
  }

  secret = ENV['JWT_SECRET']
  JWT.encode(payload, secret, 'HS256')
end




def update_bank
  @user = @current_user

  unless @user
    return render json: { error: "User not found or not logged in" }, status: :unauthorized
  end

  if params[:account_name].present? && params[:account_number].present? && params[:bank_code].present?
    verification = verify_with_paystack(params[:account_number], params[:bank_code])
    unless verification[:success]
      return render json: { error: "Bank account verification failed. Please check your details." }, status: :unprocessable_entity
    end

    paystack_name = verification[:account_name].downcase.strip
    submitted_name = params[:account_name].downcase.strip

    unless paystack_name.include?(submitted_name) || submitted_name.include?(paystack_name)
      return render json: { error: "Account name does not match. Paystack returned: #{verification[:account_name]}" }, status: :unprocessable_entity
    end
  end

  if @user.update(
    account_name: params[:account_name]&.strip,
    account_number: params[:account_number]&.strip,
    bank_code: params[:bank_code]&.strip,
    paystack_recipient_code: nil
  )
    render json: {
      success: true,
      message: "Bank details saved successfully!",
      bank_details: {
        account_name: @user.account_name,
        account_number: @user.account_number&.gsub(/\d(?=\d{4})/, '*'), # masked
        bank_name: bank_name_from_code(@user.bank_code)
      }
    }, status: :ok
  else
    render json: { error: "Failed to save bank details", details: @user.errors.full_messages }, status: :unprocessable_entity
  end
end


# app/controllers/api/v1/users_controller.rb
def banks
  # Try to read from cache first
  banks = Rails.cache.fetch("paystack_banks", expires_in: 12.hours) do
    secret_key = ENV['PAYSTACK_SECRET_KEY']
    response = HTTParty.get(
      "https://api.paystack.co/bank",
      headers: { "Authorization" => "Bearer #{secret_key}" }
    )
    if response.success?
      response["data"].map { |b| { name: b["name"], code: b["code"] } }
    else
      [] # fallback to empty array
    end
  end

  if banks.any?
    render json: banks
  else
    render json: { error: "Failed to fetch banks" }, status: :bad_request
  end
end

def bank_name_from_code(code)
  banks = Rails.cache.fetch("paystack_banks") do
    secret_key = ENV['PAYSTACK_SECRET_KEY']
    response = HTTParty.get(
      "https://api.paystack.co/bank",
      headers: { "Authorization" => "Bearer #{secret_key}" }
    )
    response.success? ? response["data"] : []
  end

  bank = banks.find { |b| b["code"] == code }
  bank ? bank["name"] : "Unknown Bank"
end


def verify_with_paystack(account_number, bank_code)
  secret = ENV["PAYSTACK_SECRET_KEY"].presence

response = HTTParty.get(
  "https://api.paystack.co/bank/resolve",
  query: { account_number: account_number, bank_code: bank_code },
  headers: { "Authorization" => "Bearer #{secret}" }
)
Rails.logger.info "PAYSTACK RESPONSE: #{response.body}"
Rails.logger.info "PAYSTACK STATUS: #{response.code}"


  if response.success? && response["status"] == true
    { success: true, account_name: response["data"]["account_name"] }
  else
    { success: false, error: response["message"] || "Verification failed" }
  end
end

# POST /sign_in

  def activate
    puts "Activation token received: #{params[:token]}"
    user = User.find_by(activation_token: params[:token])
  
    if user && !user.activated?
      puts "User found and not activated"
      # Update activation status without modifying the avatar URL
      user.update_columns(activated: true, activation_token: nil)
      puts "User activated and activation token cleared"
      render json: { message: 'Account activated successfully' }, status: :ok
    else
      puts "Invalid or already used activation token: #{params[:token]}"
      render json: { error: 'Invalid activation token' }, status: :unprocessable_entity
    end
  end
  
  
  def find_user_by_storename
    user = User.find_by(store_name: params[:store_name])
    if user
      render json: { user: user }, status: :ok
    else
      render json: { error: 'User not found.' }, status: :not_found
    end
  end

  def wish_list
    user = User.find(params[:id])
    if user
      render json: { wish_list: user.wish_list }, status: :ok
    else
      render json: { error: 'User not found.' }, status: :not_found
    end   
  end
  
  def generate_activation_token
    user = User.find_by(email: params[:email])
    if user
      if user.activated?
        render json: { message: 'User account is already activated.' }, status: :unprocessable_entity
      elsif user.activation_token_expired?
        # Generate a new activation token and set a new expiration date
        user.update(activation_token: SecureRandom.urlsafe_base64)
        user.update(activation_token_expires_at: 2.days.from_now)

        # Send the activation email with the new token
        html_template_path = File.expand_path('../../../../views/user_mailer/activation_email.html.erb', __FILE__)
        send_activation_email(user, html_template_path)

        render json: { message: 'New activation token generated. Please check your email for activation instructions.' }, status: :ok
      else
        render json: { message: 'User account is still pending activation.' }, status: :unprocessable_entity
      end
    else
      render json: { error: 'User not found.' }, status: :not_found
    end
  end

  def update
    if @user.update(user_params)
      # Generate a new JWT token for the updated user
      jwt_token = generate_jwt_token(@user)
      
      render json: { user: @user, jwt_token: jwt_token, message: "User updated successfully" }
    else
      render json: @user.errors, status: :unprocessable_entity
    end
  end

  # DELETE /users/1
  def destroy
    @user.destroy
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_user
      @user = User.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def user_params
      params.permit(:name, :email, :password, :password_confirmation, :avatar, :seller, :state, :mobile, :store_name)
    end

    def send_activation_email(user, html_template_path)
      Mailjet.configure do |config|
        config.api_key = ENV['APP_MAILJET_API_KEY']
        config.secret_key = ENV['APP_MAILJET_SECRET_KEY']
        config.api_version = 'v3.1'
      end
    
      # Replace with your Mailjet sender email and name
      sender_email = 'support@artisanshub.net'
      sender_name = 'Digital Art'
      html_content = File.read(html_template_path)
      
      # Use ERB to render dynamic content
      template = ERB.new(html_content)
      rendered_html = template.result(binding)
      
      # The rest of your code...
      
      variable_params = {
        'activation_link' => "https://fin-man.fly.dev/api/v1/activate/#{user.activation_token}"
        # Add any other variables you want to include in your email template
      }
    
      message = Mailjet::Send.create(messages: [{
        'From' => {
          'Email' => sender_email,
          'Name' => sender_name
        },
        'To' => [{
          'Email' => user.email,
          'Name' => user.name
        }],
        # 'TemplateID' => 'YOUR_MAILJET_TEMPLATE_ID',
        'Subject'=> 'Account activation',
    'TextPart'=> 'Activate your account',
    'HTMLPart'=> rendered_html,
        'Variables' => variable_params
      }])
      puts "Mailjet response: #{message.attributes.inspect}"
    end
end

# {
#   "name": "louis debroglie",
#   "email": "precious@yahoo.com",
#   "password": "eaagleclaw",
#   "password_confirmation": "eagleclaw"
# }
