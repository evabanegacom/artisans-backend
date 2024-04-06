class AddFieldsToProduct < ActiveRecord::Migration[7.0]
  def change
    add_column :products, :sold_by, :string
    add_column :products, :contact_number, :string 
    add_column :products, :product_number, :string
    add_column :products, :tags, :text, array: true, default: []
  end
end
