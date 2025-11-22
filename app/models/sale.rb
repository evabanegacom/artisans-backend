# app/models/sale.rb
class Sale < ApplicationRecord
  belongs_to :product
  belongs_to :user  # seller

  # Remove the enum — this is the source of the conflict
  # enum status: { pending: "pending", completed: "completed", expired: "expired", failed: "failed" }

  # Use scopes instead — 100% safe and clean
  scope :pending,   -> { where(status: "pending") }
  scope :completed, -> { where(status: "completed") }
  scope :expired,   -> { where(status: "expired") }
  scope :failed,    -> { where(status: "failed") }

  # Optional: human readable status
  def status_text
    status.titleize
  end

  # Optional: color for frontend
  def status_color
    case status
    when "completed" then "emerald"
    when "pending"   then "amber"
    when "expired"   then "gray"
    when "failed"    then "red"
    else "blue"
    end
  end

  # Validations
  validates :buyer_email, presence: true
  validates :buyer_name, presence: true
  validates :amount, numericality: { greater_than_or_equal_to: 0 }
#  paginates_per 20
  # For will_paginate (you already use it)
  # Remove paginates_per — it's Kaminari only!
end