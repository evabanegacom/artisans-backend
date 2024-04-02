# app/controllers/api/v1/passwords_controller.rb
class Api::V1::PasswordsController < ApplicationController

  def reset
    user = User.find_by(email: params[:email])

    if user
      # Generate reset token and send password reset email
      user.reset_token = SecureRandom.urlsafe_base64
      user.reset_token_expires_at = 2.days.from_now
      user.save(validate: false)

      send_password_reset_email(user)

      render json: { message: 'Password reset email sent. Please check your email for instructions.' }, status: :ok
    else
      render json: { error: 'User not found' }, status: :not_found
    end
  end

  def edit
    puts "Reset token received: #{params[:reset_token]}"
    @user = User.find_by(reset_token: params[:reset_token])
    puts "User found: #{@user}"
    if @user && @user.reset_token_valid?
      render json: { message: 'Reset password' }, status: :ok
    elsif @user && !@user.reset_token_valid?
      render json: { error: 'Reset token has expired' }, status: :unprocessable_entity
    else
      render json: { error: 'Invalid reset token' }, status: :unprocessable_entity
    end
  end

  def update
    user = User.find_by(reset_token: params[:reset_token])
  
    if user && user.reset_token_valid?
      new_password = params[:new_password]
      
      if user.update(password: new_password, password_confirmation: new_password, reset_token: nil)
        # Successfully updated the password
        render json: { message: 'Password reset successful' }, status: :ok
      else
        # Failed to update the password
        render json: { error: user.errors.full_messages }, status: :unprocessable_entity
      end
    elsif user && !user.reset_token_valid?
      # Reset token has expired
      render json: { error: 'Reset token has expired' }, status: :unprocessable_entity
    else
      # Invalid reset token
      render json: { error: 'Invalid reset token' }, status: :unprocessable_entity
    end
  end  

  private

  def send_password_reset_email(user)
    Mailjet.configure do |config|
      config.api_key = ENV['APP_API_KEY'] || 'd531ec7b0745a031ceae938c4730e889'
      config.secret_key = ENV['APP_SECRET_KEY'] || '0ca4ac8ba4e43cf761f3a9bc07df7a45'
      config.api_version = 'v3.1' # or your preferred Mailjet API version
    end
    # Replace with your Mailjet sender email and name
    sender_email = 'udegbue69@gmail.com'
    sender_name = 'Financial wellness'
    html_template_path = File.expand_path('../../../../views/user_mailer/password_reset_email.html.erb', __FILE__)

    # Use ERB to render dynamic content
    template = ERB.new(File.read(html_template_path))
    rendered_html = template.result(binding)

    # The rest of your code...

    variable_params = {
      'reset_link' => "https://your-app-domain.com/reset-password/#{user.reset_token}"
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
      'Subject' => 'Password Reset Instructions',
      'TextPart' => 'Follow the link to reset your password',
      'HTMLPart' => rendered_html,
      'Variables' => variable_params
    }])
    puts "Mailjet response: #{message.attributes.inspect}"
  end
end
