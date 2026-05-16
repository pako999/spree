module Api
  module V1
    class ClubSchedulesController < BaseController
      def index
        schedules = ClubSchedule.order(:day_of_week)
        render json: schedules.map { |s|
          {
            id: s.id, day_of_week: s.day_of_week, day_name: s.day_name,
            opens_at: s.opens_at&.strftime('%H:%M'), closes_at: s.closes_at&.strftime('%H:%M'),
            closed: s.closed, label: s.label
          }
        }
      end

      def show
        schedule = ClubSchedule.find(params[:id])
        render json: schedule
      end

      def create
        schedule = ClubSchedule.new(schedule_params)
        if schedule.save
          render json: schedule, status: :created
        else
          render_error(schedule.errors.full_messages.join(', '))
        end
      end

      def update
        schedule = ClubSchedule.find(params[:id])
        if schedule.update(schedule_params)
          render json: schedule
        else
          render_error(schedule.errors.full_messages.join(', '))
        end
      end

      def destroy
        ClubSchedule.find(params[:id]).destroy
        head :no_content
      end

      private

      def schedule_params
        params.permit(:day_of_week, :opens_at, :closes_at, :closed, :label)
      end
    end
  end
end
