class EmailFlowMailer < ApplicationMailer
  def send_flow_email(flow, customer, send_record)
    @flow = flow
    @customer = customer
    @send_record = send_record
    @body = flow.render_body(customer.preferred_language, customer: customer)
    @subject = flow.render_subject(customer.preferred_language, customer: customer)
    @unsubscribe_url = unsubscribe_url(token: customer.unsubscribe_token)
    @tracking_url = tracking_open_url(token: send_record.tracking_token)

    I18n.with_locale(customer.preferred_language) do
      mail(
        to: customer.email,
        subject: @subject,
        list_unsubscribe: "<#{@unsubscribe_url}>"
      ) do |format|
        format.html
      end
    end

    send_record.mark_sent!
  end
end
