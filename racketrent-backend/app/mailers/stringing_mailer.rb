class StringingMailer < ApplicationMailer
  def order_received(order)
    @order = order
    @customer = order.stringing_customer
    I18n.with_locale(@customer.preferred_language) do
      mail(to: @customer.email, subject: I18n.t('mailer.stringing.received.subject'))
    end
  end

  def ready_for_pickup(order)
    @order = order
    @customer = order.stringing_customer
    @pickup_times = ClubSchedule.next_open_days(3)
    I18n.with_locale(@customer.preferred_language) do
      mail(to: @customer.email, subject: I18n.t('mailer.stringing.ready.subject'))
    end
  end
end
