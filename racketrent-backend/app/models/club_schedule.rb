class ClubSchedule < ApplicationRecord
  validates :day_of_week, presence: true, uniqueness: true, inclusion: { in: 0..6 }
  validates :opens_at, :closes_at, presence: true

  scope :open_days, -> { where(closed: false).order(:day_of_week) }

  def day_name
    Date::DAYNAMES[day_of_week]
  end

  def self.next_open_days(count = 3)
    today = Date.current
    open_schedules = open_days.to_a
    return [] if open_schedules.empty?

    results = []
    date = today
    while results.size < count && date < today + 14
      schedule = open_schedules.find { |s| s.day_of_week == date.wday }
      if schedule
        results << {
          date: date,
          day_name: schedule.day_name,
          opens_at: schedule.opens_at.strftime('%H:%M'),
          closes_at: schedule.closes_at.strftime('%H:%M')
        }
      end
      date += 1.day
    end
    results
  end
end
