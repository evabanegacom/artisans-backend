Rails.application.routes.draw do
  root 'static#index'
  namespace :api do
    namespace :v1 do
      resources :users, only: %i[create index destroy update show]

      post '/activate', to: 'users#activate'

      get '/user_by_storename', to: 'users#find_user_by_storename'
      
      post '/sign_in', to: 'users#sign_in'

      get 'monthly_savings', to: 'aggregates#savings'
      
      post 'generate_activation_token', to: 'users#generate_activation_token'
      # Password reset routes
      post '/password/reset', to: 'passwords#reset', as: 'reset_password'
      get '/password/reset/:reset_token', to: 'passwords#edit', as: 'edit_password'
      put '/password/update', to: 'passwords#update', as: 'update_password'
      resources :products do
        collection do
          get 'user_products'
          get 'products_by_category'
          get 'search'
          get 'products_by_storename'
          get 'get_product_by_product_number'
          get 'get_picture_to_edit'
        end
      end
    end
  end
end
