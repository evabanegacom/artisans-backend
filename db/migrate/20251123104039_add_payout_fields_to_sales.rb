# db/migrate/xxxx_add_payout_fields_to_sales.rb
class AddPayoutFieldsToSales < ActiveRecord::Migration[7.0]
  def change
    add_column :sales, :payable_at, :datetime
    add_column :sales, :wallet_credited_at, :datetime

    # Backfill for existing completed sales
    reversible do |dir|
      dir.up do
        Sale.where(status: "completed", payable_at: nil)
            .update_all("payable_at = downloaded_at + INTERVAL '24 hours'")
      end
    end
  end
end