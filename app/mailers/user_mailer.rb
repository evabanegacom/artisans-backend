# app/mailers/user_mailer.rb
class UserMailer < ApplicationMailer

    def password_reset_email(user)
        @user = user
        @reset_url = "#{ENV['APP_BASE_URL']}/password/reset/#{user.reset_token}"
    
        mail(to: user.email, subject: 'Reset Your Password')
      end
      
    def activation_email(user)
      @user = user
      @activation_url = "#{ENV['APP_BASE_URL']}/activate/#{user.activation_token}"
  
      mail(to: user.email, subject: 'Activate Your Account')
    end
  end
  