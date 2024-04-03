class AddPicturesToProducts < ActiveRecord::Migration[7.0]
  def change
    add_column :products, :pictureOne, :string
    add_column :products, :pictureTwo, :string
    add_column :products, :pictureThree, :string
    add_column :products, :pictureFour, :string
  end
end
