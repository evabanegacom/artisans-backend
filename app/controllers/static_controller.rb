class StaticController < ApplicationController
    def index
      render json: { message: ' hello welcome to our page'}
    end
  end