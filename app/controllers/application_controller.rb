# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
    # This runs on every request — auto-credits wallet when 24h escrow is over
    before_action :authenticate_user_from_token!
    before_action :credit_available_payouts, if: -> { @current_user.present? }
  
    private
  
    # Replaces current_user — works with your JWT setup
    def authenticate_user_from_token!
        auth_header = request.headers["Authorization"]
      
        # Return 401 if no Authorization header
        unless auth_header&.start_with?("Bearer ")
          return render json: { error: "Token missing" }, status: :unauthorized
        end
      
        # Extract the token string
        token = auth_header.split(" ").last
      
        # Remove surrounding quotes if present (common if frontend wraps token in quotes)
        token = token.delete_prefix('"').delete_suffix('"')
      
        begin
          # Decode the JWT using the same secret as generation
          payload = JWT.decode(token, Rails.application.secrets.secret_key_base, true, algorithm: 'HS256').first
      
          # Find the user by user_id in the payload
          @current_user = User.find_by(id: payload['user_id'])
          puts "Authenticated user: #{@current_user&.email}"
      
          # Return 401 if user not found
          return render json: { error: "Invalid user" }, status: :unauthorized unless @current_user
      
        rescue JWT::DecodeError, JWT::ExpiredSignature, JWT::VerificationError => e
          # Return 401 if token invalid or expired
          return render json: { error: "Invalid or expired token" }, status: :unauthorized
        end
      end      
      
  
    # This is your magic 24-hour payout system (no jobs!)
    def credit_available_payouts
      return unless @current_user&.seller?
  
      due_sales = @current_user.sales
                               .where("payable_at <= ? AND wallet_credited_at IS NULL", Time.current)
  
      return if due_sales.none?
  
      total_amount = due_sales.sum(:amount)
  
      ApplicationRecord.transaction do
        @current_user.wallet.update!(balance: @current_user.wallet.balance + total_amount)
        due_sales.update_all(wallet_credited_at: Time.current)
      end
  
      # Optional: Log or notify
      Rails.logger.info "Credited ₦#{total_amount} to #{@current_user.email}'s wallet"
    end
  
    # Helper so you can use current_user in other controllers
    def current_user
      @current_user
    end
  end