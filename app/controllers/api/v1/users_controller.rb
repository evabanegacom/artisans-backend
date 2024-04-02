require 'mailjet'
class Api::V1::UsersController < ApplicationController
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
def create
  user = User.new(user_params)

  if user.save
    user.update(activation_token: SecureRandom.urlsafe_base64)
    user.update(activation_token_expires_at: 2.days.from_now)

    # Generate a JWT token for the user
    jwt_token = generate_jwt_token(user)

    # Send activation email
    html_template_path = File.expand_path('../../../../views/user_mailer/activation_email.html.erb', __FILE__)
    send_activation_email(user, html_template_path)

    render json: { message: 'Account created check your email for activation instructions.', jwt_token: jwt_token }, status: :created
  else
    render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
  end
end

# Generate JWT token for user
def generate_jwt_token(user)
  payload = { user_id: user.id, exp: 1.day.from_now.to_i, email: user.email, name: user.name, avatar: user.avatar, activated: user.activated}
  JWT.encode(payload, Rails.application.secrets.secret_key_base)
end

# def logged_in_user
#   if @current_user
#     render json: { user: @current_user }, status: :ok
#   else
#     render json: { error: 'No user logged in.' }, status: :unprocessable_entity
#   end
# end

# POST /sign_in
def sign_in
  user = User.find_by(email: params[:email])

  if user && user.authenticate(params[:password])
    jwt_token = generate_jwt_token(user)
    render json: { message: 'Sign-in successful.', jwt_token: jwt_token, status: :ok }
  else
    render json: { error: 'Invalid credentials.' }, status: :unauthorized
  end
end

  def activate
    puts "Activation token received: #{params[:token]}"
    user = User.find_by(activation_token: params[:token])

    # user = User.find_by(activation_token: params[:activation_token])
    puts "User found: #{user}"
    if user && !user.activated?
      puts "User found and not activated"
      user.update(activated: true)
      user.save(validate: false)
      # user.skip_password_validation = true  # Skip password validation
      puts "User updated"
      # user.activation_token = nil
      render json: { message: 'Account activated successfully' }, status: :ok
    else
      render json: { error: 'Invalid activation token' }, status: :unprocessable_entity
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

  # PATCH/PUT /users/1
  def update
    if @user.update(user_params)
      render json: @user
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
      params.permit(:name, :email, :password, :password_confirmation, :avatar)
    end

    def send_activation_email(user, html_template_path)
      Mailjet.configure do |config|
        config.api_key = ENV['APP_API_KEY'] || 'd531ec7b0745a031ceae938c4730e889'
        config.secret_key = ENV['APP_SECRET_KEY'] || '0ca4ac8ba4e43cf761f3a9bc07df7a45'
        config.api_version = 'v3.1'
      end
    
      # Replace with your Mailjet sender email and name
      sender_email = 'udegbue69@gmail.com'
      sender_name = 'Financial wellness'
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
