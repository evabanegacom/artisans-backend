# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.0].define(version: 2025_11_22_063450) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "products", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.decimal "price"
    t.string "category"
    t.integer "quantity"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "pictureOne"
    t.string "pictureTwo"
    t.string "pictureThree"
    t.string "pictureFour"
    t.string "sold_by"
    t.string "contact_number"
    t.string "product_number"
    t.string "tags", default: [], array: true
    t.string "download_file"
    t.index ["user_id"], name: "index_products_on_user_id"
  end

  create_table "sales", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.bigint "user_id", null: false
    t.string "buyer_name", null: false
    t.string "buyer_email", null: false
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.string "currency", default: "NGN", null: false
    t.string "status", default: "pending", null: false
    t.string "seller", null: false
    t.datetime "downloaded_at"
    t.string "token_used", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["buyer_email"], name: "index_sales_on_buyer_email"
    t.index ["product_id", "created_at"], name: "index_sales_on_product_id_and_created_at"
    t.index ["product_id"], name: "index_sales_on_product_id"
    t.index ["status"], name: "index_sales_on_status"
    t.index ["token_used"], name: "index_sales_on_token_used", unique: true
    t.index ["user_id"], name: "index_sales_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.string "password_digest"
    t.string "activation_token"
    t.boolean "activated", default: false
    t.datetime "reset_token_expires_at"
    t.datetime "activation_token_expires_at"
    t.string "reset_token"
    t.boolean "seller"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "avatar"
    t.string "state"
    t.string "store_name"
    t.string "mobile"
  end

  add_foreign_key "products", "users"
  add_foreign_key "sales", "products"
  add_foreign_key "sales", "users"
end
