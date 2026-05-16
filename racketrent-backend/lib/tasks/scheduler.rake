namespace :scheduler do
  desc 'Send rental return reminders for rentals due today'
  task rental_reminders: :environment do
    RentalReminderJob.perform_later
    puts "Rental reminder job queued"
  end

  desc 'Process automated email flows (run daily)'
  task email_flows: :environment do
    EmailFlowProcessorJob.perform_later
    puts "Email flow processor job queued"
  end

  desc 'Run all daily tasks'
  task daily: :environment do
    Rake::Task['scheduler:rental_reminders'].invoke
    Rake::Task['scheduler:email_flows'].invoke
    puts "All daily tasks queued"
  end
end
