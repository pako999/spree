class EmailFlowProcessorJob < ApplicationJob
  def perform
    EmailFlow.active.automated.find_each do |flow|
      flow.customers_due.find_each do |customer|
        next unless customer.marketing_opt_in

        send_record = flow.email_flow_sends.create!(
          stringing_customer: customer,
          stringing_order: customer.last_stringing_order
        )
        EmailFlowMailer.send_flow_email(flow, customer, send_record).deliver_later
      end
    end
  end
end
