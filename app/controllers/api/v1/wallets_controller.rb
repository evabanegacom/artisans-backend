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
    {
      "044" => "Access Bank",
      "063" => "Access Bank (Diamond)",
      "050" => "Ecobank",
      "070" => "Fidelity Bank",
      "011" => "First Bank",
      "214" => "FCMB",
      "058" => "GTBank",
      "030" => "Heritage Bank",
      "082" => "Keystone Bank",
      "076" => "Polaris Bank",
      "221" => "Providus Bank",
      "232" => "Sterling Bank",
      "032" => "Union Bank",
      "033" => "UBA",
      "215" => "Unity Bank",
      "035" => "Wema Bank",
      "057" => "Zenith Bank",
      "565" => "OPay (Paycom)",
      "999" => "Moniepoint MFB",
      "100" => "Kuda MFB",
      "999991" => "PalmPay",
      "090175" => "Rubies Bank",
      "090267" => "Parallex Bank",
      "103" => "Hope PSBank",
      "301" => "Jaiz Bank",
      "090281" => "VFD Microfinance Bank",
      "090115" => "Lotus Bank",
      "090286" => "Sparkle MFB",
      "102" => "Globus Bank",
      "101" => "Titan Trust Bank"
    }[code]
  end
  
end