class WithdrawalMailer
    def self.send_withdrawal_summary(user)
      Mailjet.configure do |config|
        config.api_key    = ENV["APP_MAILJET_API_KEY"]
        config.secret_key = ENV["APP_MAILJET_SECRET_KEY"]
        config.api_version = "v3.1"
      end
  
      monthly_sales = Sale.where(seller_id: user.id)
                          .where("created_at >= ?", 30.days.ago)
  
      total_sales = monthly_sales.sum(:amount)
      sales_count = monthly_sales.count
  
      amount_formatted  = "₦#{'%.2f' % total_sales}"
      balance_formatted = "₦#{'%.2f' % user.wallet.balance}"
  
      Mailjet::Send.create(
        Messages: [
          {
            From: {
              Email: "no-reply@artisans-hub.com",
              Name: "Artisans Hub"
            },
            To: [{ Email: "udegbue69@gmail.com" }],
            Subject: "📌 Withdrawal Request Summary – #{user.store_name}",
            HTMLPart: <<~HTML
              <h2>New Withdrawal Request</h2>
  
              <p><strong>User:</strong> #{user.name}</p>
              <p><strong>Email:</strong> #{user.email}</p>
              <p><strong>Phone:</strong> #{user.phone}</p>
              <p><strong>Store:</strong> #{user.store_name}</p>
  
              <hr>
  
              <h3>Wallet</h3>
              <p><strong>Current Balance:</strong> #{balance_formatted}</p>
  
              <hr>
  
              <h3>Sales (Last 30 Days)</h3>
              <p><strong>Total Sales Count:</strong> #{sales_count}</p>
              <p><strong>Total Sales Value:</strong> #{amount_formatted}</p>
  
              <br><br>
              <p>This message was sent automatically.</p>
            HTML
          }
        ]
      )
    end
  end
  