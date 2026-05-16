class RentalMailer < ApplicationMailer
  def rental_confirmation(rental)
    @rental = rental
    @customer = rental.customer
    @racket = rental.racket
    I18n.with_locale(@customer.preferred_language) do
      mail(to: @customer.email, subject: I18n.t('mailer.rental.confirmation.subject'))
    end
  end

  def rental_extended(rental, extra_days)
    @rental = rental
    @customer = rental.customer
    @extra_days = extra_days
    I18n.with_locale(@customer.preferred_language) do
      mail(to: @customer.email, subject: I18n.t('mailer.rental.extended.subject'))
    end
  end

  def return_reminder(rental)
    @rental = rental
    @customer = rental.customer
    @racket = rental.racket
    I18n.with_locale(@customer.preferred_language) do
      mail(to: @customer.email, subject: I18n.t('mailer.rental.reminder.subject'))
    end
  end
end
