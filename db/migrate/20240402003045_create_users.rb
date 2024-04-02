class CreateUsers < ActiveRecord::Migration[7.0]
  def change
    create_table :users do |t|
      t.string :name
      t.string :email
      t.string :password_digest
      t.string :activation_token
      t.boolean :activated
      t.datetime :reset_token_expires_at
      t.datetime :activation_token_expires_at
      t.string :reset_token
      t.boolean :seller

      t.timestamps
    end
  end
end
