class AddUuidToProducts < ActiveRecord::Migration[7.0]
  def change
    add_column :products, :uuid, :uuid, default: "gen_random_uuid()", null: false
    add_index :products, :uuid, unique: true
  end
end
