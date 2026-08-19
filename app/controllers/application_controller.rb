<<<<<<< HEAD
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
    # This runs on every request — auto-credits wallet when 24h escrow is over
    protect_from_forgery with: :null_session

    # Set current_user before every action (optional: only for API requests)
    before_action :set_current_user
    before_action :credit_available_payouts, if: -> { @current_user.present? }
  
    private

    def set_current_user
      return if @current_user.present?
  
      auth_header = request.headers['Authorization']
      return unless auth_header&.start_with?('Bearer ')
  
      token = auth_header.split(' ').last.delete_prefix('"').delete_suffix('"')
  
      begin
        payload = JWT.decode(token, ENV['JWT_SECRET'], true, algorithm: 'HS256').first
        @current_user = User.find_by(uuid: payload['user_id'])
        puts "Authenticated user: #{@current_user.email}" if @current_user
      rescue JWT::DecodeError, JWT::ExpiredSignature, JWT::VerificationError
        @current_user = nil
      end
    end

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
    
      Rails.logger.info "Credited ₦#{total_amount} to #{@current_user.email}'s wallet"
    end
  
    # Make current_user accessible in controllers and views
    helper_method :current_user
    def current_user
      @current_user
    end

  end
=======
class ApplicationController < ActionController::API
end
>>>>>>> 5f39edc0114fca8aa6de2aff3d76971708c304ab
