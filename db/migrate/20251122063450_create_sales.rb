class CreateSales < ActiveRecord::Migration[7.0] # or 7.1 depending on your Rails version
  def change
    create_table :sales do |t|
      t.references :product, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true # seller

      t.string  :buyer_name, null: false
      t.string  :buyer_email, null: false
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string  :currency, default: "NGN", null: false
      t.string  :status, default: "pending", null: false
      t.string  :seller, null: false
      # addd downloaded_at to track when the download link was used
      t.datetime :downloaded_at
      t.string  :token_used, null: false # unique token for download link

      t.timestamps
    end

    # Indexes for performance & uniqueness
    add_index :sales, :token_used, unique: true
    add_index :sales, :buyer_email
    add_index :sales, [:product_id, :created_at]
    add_index :sales, :status
  end
end