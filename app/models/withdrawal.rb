class Withdrawal < ApplicationRecord
    belongs_to :user
  
    validates :amount, presence: true, numericality: { greater_than: 0 }
    # validates :status, presence: true
    # validates :paystack_ref, presence: true
  
    # Scope for recent withdrawals
    scope :recent, -> { order(created_at: :desc) }
  end
  