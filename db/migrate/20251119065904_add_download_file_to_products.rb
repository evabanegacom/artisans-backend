class AddDownloadFileToProducts < ActiveRecord::Migration[7.0]
  def change
    add_column :products, :download_file, :string, null: true
  end
end
