class UnsubscribeController < ApplicationController
  def show
    @customer = StringingCustomer.find_by!(unsubscribe_token: params[:token])
    render json: { name: @customer.full_name, email: @customer.email, unsubscribed: !@customer.marketing_opt_in }
  end

  def update
    customer = StringingCustomer.find_by!(unsubscribe_token: params[:token])
    customer.unsubscribe!
    render json: { message: 'You have been unsubscribed from marketing emails.' }
  end
end
