# app/controllers/api/v1/wallets_controller.rb
class Api::V1::WalletsController < ApplicationController

  def show
    @user = @current_user
    wallet = @user.wallet
    pending_sales = @user.sales
                         .where("payable_at > ? AND wallet_credited_at IS NULL", Time.current)

    available_balance = wallet&.balance || 0.0
    pending_balance   = pending_sales.sum(:amount).to_f

    render json: {
      available_balance: available_balance.round(2),
      pending_balance: pending_balance.round(2),
      total_balance: (available_balance + pending_balance).round(2),
      bank_details: {
        account_name: @user.account_name,
        account_number: @user.account_number&.gsub(/\d(?=\d{4})/, '*'),
        bank_name: bank_name_from_code(@user.bank_code),
        bank_code: @user.bank_code
      }.compact,
      pending_sales: pending_sales.select(:id, :amount, :payable_at).map do |sale|
        {
          id: sale.id,
          amount: sale.amount.to_f,
          payable_at: sale.payable_at.iso8601,
          hours_left: ((sale.payable_at - Time.current) / 3600).ceil.clamp(0, nil)
        }
      end
    }, status: :ok
  end

  private

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
  
end