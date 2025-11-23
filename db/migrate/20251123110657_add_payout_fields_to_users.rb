class AddPayoutFieldsToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :account_name, :string, null: true
    add_column :users, :account_number, :string, null: true
    add_column :users, :bank_code, :string, null: true
    add_column :users, :paystack_recipient_code, :string, null: true

    # Optional: Add indexes
    add_index :users, :account_number
    add_index :users, :paystack_recipient_code, unique: true
  end
end
