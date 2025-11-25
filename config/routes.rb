# config/routes.rb
Rails.application.routes.draw do
  root 'static#index'

  namespace :api do
    namespace :v1 do
      resources :users, only: %i[create index destroy update show]

      # === AUTH & USER ROUTES ===
      post   '/activate',                  to: 'users#activate'
      post   '/sign_in',                   to: 'users#sign_in'
      post   '/generate_activation_token', to: 'users#generate_activation_token'
      get    '/user_by_storename',         to: 'users#find_user_by_storename'

      # === PASSWORD RESET ===
      post   '/password/reset',            to: 'passwords#reset'
      get    '/password/reset/:reset_token', to: 'passwords#edit'
      put    '/password/update',           to: 'passwords#update'

      # === WALLET & WITHDRAWALS (NEW) ===
      get    '/wallet',                    to: 'wallets#show'           # → Shows balance + pending
      post   '/verify_bank',               to: 'users#verify_bank'      # → Paystack name verification
      post   '/update_bank',               to: 'users#update_bank'      # → Save bank details
      post   '/withdraw',                  to: 'withdrawals#create'     # → Initiate payout
      get    'paystack/banks',             to: 'users#banks'

      # === PRODUCTS ===
      resources :products do
        collection do
          get 'user_products'
          get 'products_by_category'
          get 'search'
          get 'products_by_storename'
          get 'get_product_by_product_number'
          get 'get_picture_to_edit'
          get 'sales_by_seller'
        end

        member do
          post 'send_download_link'
          get  'download'
        end
      end

      # === OTHER ===
      get 'monthly_savings', to: 'aggregates#savings'
    end
  end
end
