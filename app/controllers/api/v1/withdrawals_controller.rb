# app/controllers/api/v1/withdrawals_controller.rb
class Api::V1::WithdrawalsController < ApplicationController
  
  def create
    amount = params[:amount].to_d
  
    # Minimum withdrawal
    if amount < 1000
      return render json: { error: "Minimum withdrawal is ₦1,000" }, status: :bad_request
    end
  
    if @current_user.wallet.balance < amount
      return render json: { error: "Insufficient balance" }, status: :unprocessable_entity
    end
  
    # Get or create Paystack recipient
    recipient_code = ensure_paystack_recipient
  
    # Initiate transfer from your Paystack balance
    # response = HTTParty.post(
    #   "https://api.paystack.co/transfer",
    #   body: {
    #     source: "balance",
    #     amount: (amount * 100).to_i, # kobo
    #     recipient: recipient_code,
    #     reason: "Marketplace Payout",
    #     reference: "wd_#{SecureRandom.hex(8)}"
    #   }.to_json,
    #   headers: paystack_headers
    # )
  
    # if response.success? && response["status"] == true
    #   data = response["data"]
  
    #   # Deduct from wallet
    #   @current_user.wallet.update!(balance: @current_user.wallet.balance - amount)
  
    #   # Record withdrawal
    #   Withdrawal.create!(
    #     user_id: @current_user.id,
    #     amount: amount,
    #     status: data["status"], 
    #     paystack_ref: data["reference"],
    #     paystack_status: data["status"]
    #   )
  
    #   # 📧 SEND EMAIL IMMEDIATELY WHEN WITHDRAWAL IS CREATED
    #   WithdrawalMailer.send_withdrawal_summary(@current_user)
  
    #   render json: {
    #     success: true,
    #     message: "Withdrawal initiated!",
    #     reference: data["reference"],
    #     status: data["status"]
    #   }, status: :created
  
    # else
    #   error = response["message"] || "Transfer failed"
    #   render json: { error: error }, status: :unprocessable_entity
    # end

    @current_user.wallet.update!(balance: @current_user.wallet.balance - amount)
  
      # Record withdrawal
      Withdrawal.create!(
        user_id: @current_user.id,
        amount: amount,
        # status: data["status"], 
        status: 'Completed',
        # paystack_ref: data["reference"],
        paystack_ref: "wd_#{SecureRandom.hex(8)}",
        paystack_status: 'completed'
      )
  
      # 📧 SEND EMAIL IMMEDIATELY WHEN WITHDRAWAL IS CREATED
      WithdrawalMailer.send_withdrawal_summary(@current_user, amount)
  
      render json: {
        success: true,
        message: "Withdrawal initiated!",
        # reference: data["reference"],
        # status: data["status"]
        reference: "wd_#{SecureRandom.hex(8)}",
        status: 'completed'
      }, status: :created
  
  end
  
    
      private
    
      # Optional: Convert bank code to name
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
  
    private
  
    def ensure_paystack_recipient
      return @current_user.paystack_recipient_code if @current_user.paystack_recipient_code.present?
  
      # Make sure bank details exist
      unless @current_user.account_name.present? && @current_user.account_number.present? && @current_user.bank_code.present?
        render json: { error: "Please add your bank details first" }, status: :unprocessable_entity
        return
      end
  
      resp = HTTParty.post(
        "https://api.paystack.co/transferrecipient",
        body: {
          type: "nuban",
          name: @current_user.account_name,
          account_number: @current_user.account_number,
          bank_code: @current_user.bank_code,
          currency: "NGN"
        }.to_json,
        headers: paystack_headers
      )
  
      if resp.success?
        code = resp["data"]["recipient_code"]
        @current_user.update!(paystack_recipient_code: code)
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