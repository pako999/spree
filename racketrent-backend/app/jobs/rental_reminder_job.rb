class RentalReminderJob < ApplicationJob
  def perform
    Rental.due_today.includes(:customer, :racket).find_each do |rental|
      RentalMailer.return_reminder(rental).deliver_later
    end
  end
end
