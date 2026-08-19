# config/initializers/paystack_cache.rb
Rails.application.config.after_initialize do
    Rails.cache.fetch("paystack_banks", expires_in: 12.hours) do
      secret_key = ENV['PAYSTACK_SECRET_KEY']
      response = HTTParty.get(
        "https://api.paystack.co/bank",
        headers: { "Authorization" => "Bearer #{secret_key}" }
      )
      response.success? ? response["data"] : []
    end
  end
  