class Wallet < ApplicationRecord
  belongs_to :user
  def credit!(amount)
    self.balance += amount
    save!
  end
end
