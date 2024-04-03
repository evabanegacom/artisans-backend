class AdddFieldsToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :state, :string
    add_column :users, :store_name, :string
    add_column :users, :mobile, :string
  end
end
