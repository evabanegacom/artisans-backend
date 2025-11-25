class CreateWithdrawals < ActiveRecord::Migration[7.0]
  def change
    create_table :withdrawals do |t|  # remove id: :uuid
  
      t.bigint :user_id, null: false  # use bigint, not uuid

      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :status
      t.string :paystack_ref
      t.string :paystack_status

      t.timestamps
    end

    add_index :withdrawals, :user_id
    add_foreign_key :withdrawals, :users, column: :user_id
  end
end
