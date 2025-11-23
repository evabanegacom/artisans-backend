# app/controllers/api/v1/withdrawals_controller.rb
class Api::V1::WithdrawalsController < ApplicationController
    before_action :authenticate_user_from_token!
  
    def create
      amount = params[:amount].to_d
  
      # Minimum withdrawal
      if amount < 1000
        return render json: { error: "Minimum withdrawal is ₦1,000" }, status: :bad_request
      end
  
      if @user.wallet.balance < amount
        return render json: { error: "Insufficient balance" }, status: :unprocessable_entity
      end
  
      # Get or create Paystack recipient
      recipient_code = ensure_paystack_recipient
  
      # Initiate transfer from your Paystack balance
      response = HTTParty.post(
        "https://api.paystack.co/transfer",
        body: {
          source: "balance",
          amount: (amount * 100).to_i, # in kobo
          recipient: recipient_code,
          reason: "Marketplace Payout",
          reference: "wd_#{SecureRandom.hex(8)}"
        }.to_json,
        headers: paystack_headers
      )
  
      if response.success? && response["status"] == true
        data = response["data"]
  
        # Deduct from wallet
        @user.wallet.update!(balance: @user.wallet.balance - amount)
  
        # Record withdrawal
        Withdrawal.create!(
          user_id: @user.id,
          amount: amount,
          status: data["status"], # "success", "otp", or "failed"
          paystack_ref: data["reference"],
          paystack_status: data["status"]
        )
  
        render json: {
          success: true,
          message: "Withdrawal initiated!",
          reference: data["reference"],
          status: data["status"]
        }, status: :created
  
      else
        error = response["message"] || "Transfer failed"
        render json: { error: error }, status: :unprocessable_entity
      end
    end

    def show
        wallet = @user.wallet
        pending_sales = @user.sales
                             .where("payable_at > ? AND wallet_credited_at IS NULL", Time.current)
    
        available_balance = wallet.balance.to_f
        pending_balance   = pending_sales.sum(:amount).to_f
    
        render json: {
          available_balance: available_balance,
          pending_balance: pending_balance,
          total_balance: available_balance + pending_balance,
          bank_details: {
            account_name: @user.account_name,
            account_number: @user.account_number&.gsub(/\d(?=\d{4})/, '*'), # mask number
            bank_name: bank_name_from_code(@user.bank_code),
            bank_code: @user.bank_code
          }.compact, # removes nil fields
          pending_sales: pending_sales.select(:id, :amount, :payable_at).map do |sale|
            {
              id: sale.id,
              amount: sale.amount.to_f,
              payable_at: sale.payable_at.iso8601,
              hours_left: ((sale.payable_at - Time.current) / 1.hour).ceil
            }
          end
        }, status: :ok
      end
    
      private
    
      def authenticate_user_from_token!
        auth_header = request.headers["Authorization"]
        return render json: { error: "Token missing" }, status: :unauthorized unless auth_header&.start_with?("Bearer ")
    
        token = auth_header.split(" ").last
        begin
          payload = JWT.decode(token, Rails.application.secret_key_base, true, algorithm: "HS256").first
          @user = User.find(payload["user_id"])
        rescue JWT::DecodeError, JWT::ExpiredSignature, ActiveRecord::RecordNotFound
          return render json: { error: "Invalid or expired token" }, status: :unauthorized
        end
      end
    
      # Optional: Convert bank code to name
      def bank_name_from_code(code)
        {
          "044" => "Access Bank",
          "063" => "Access Bank (Diamond)",
          "050" => "Ecobank",
          "070" => "Fidelity Bank",
          "011" => "First Bank",
          "214" => "First City Monument Bank",
          "058" => "Guaranty Trust Bank",
          "030" => "Heritage Bank",
          "082" => "Keystone Bank",
          "076" => "Polaris Bank",
          "039" => "Stanbic IBTC Bank",
          "232" => "Sterling Bank",
          "032" => "Union Bank",
          "033" => "United Bank for Africa",
          "215" => "Unity Bank",
          "035" => "Wema Bank",
          "057" => "Zenith Bank"
        }[code]
      end
  
    private
  
    def ensure_paystack_recipient
      return @user.paystack_recipient_code if @user.paystack_recipient_code.present?
  
      # Make sure bank details exist
      unless @user.account_name.present? && @user.account_number.present? && @user.bank_code.present?
        render json: { error: "Please add your bank details first" }, status: :unprocessable_entity
        return
      end
  
      resp = HTTParty.post(
        "https://api.paystack.co/transferrecipient",
        body: {
          type: "nuban",
          name: @user.account_name,
          account_number: @user.account_number,
          bank_code: @user.bank_code,
          currency: "NGN"
        }.to_json,
        headers: paystack_headers
      )
  
      if resp.success?
        code = resp["data"]["recipient_code"]
        @user.update!(paystack_recipient_code: code)
        code
      else
        render json: { error: "Failed to link bank account" }, status: :unprocessable_entity
        nil
      end
    end
  
    def paystack_headers
      {
        "Authorization" => "Bearer #{ENV['PAYSTACK_SECRET_KEY']}",
        "Content-Type" => "application/json"
      }
    end
  end