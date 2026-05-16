module Api
  module V1
    class EmailFlowsController < BaseController
      def index
        flows = EmailFlow.order(:name)
        render json: flows.map { |f| flow_json(f) }
      end

      def show
        flow = EmailFlow.find(params[:id])
        render json: flow_json(flow)
      end

      def create
        flow = EmailFlow.new(flow_params)
        if flow.save
          render json: flow_json(flow), status: :created
        else
          render_error(flow.errors.full_messages.join(', '))
        end
      end

      def update
        flow = EmailFlow.find(params[:id])
        if flow.update(flow_params)
          render json: flow_json(flow)
        else
          render_error(flow.errors.full_messages.join(', '))
        end
      end

      def destroy
        EmailFlow.find(params[:id]).destroy
        head :no_content
      end

      def send_to_customers
        flow = EmailFlow.find(params[:id])
        customer_ids = params[:customer_ids] || []
        customers = StringingCustomer.where(id: customer_ids)

        sent_count = 0
        customers.each do |customer|
          send_record = flow.email_flow_sends.create!(stringing_customer: customer)
          EmailFlowMailer.send_flow_email(flow, customer, send_record).deliver_later
          sent_count += 1
        end

        render json: { sent_count: sent_count }
      end

      def bulk_send
        flow = EmailFlow.find(params[:email_flow_id])
        min_days_inactive = params[:min_days_inactive]&.to_i

        customers = StringingCustomer.subscribed
        customers = customers.inactive_for(min_days_inactive) if min_days_inactive

        sent_count = 0
        customers.find_each do |customer|
          next if flow.email_flow_sends.exists?(stringing_customer: customer)
          send_record = flow.email_flow_sends.create!(stringing_customer: customer)
          EmailFlowMailer.send_flow_email(flow, customer, send_record).deliver_later
          sent_count += 1
        end

        render json: { sent_count: sent_count }
      end

      def history
        flow = EmailFlow.find(params[:id])
        sends = flow.email_flow_sends.includes(:stringing_customer).recent.limit(100)
        render json: sends.map { |s|
          {
            id: s.id, status: s.status, sent_at: s.sent_at, opened_at: s.opened_at,
            customer: { id: s.stringing_customer.id, name: s.stringing_customer.full_name, email: s.stringing_customer.email }
          }
        }
      end

      private

      def flow_params
        params.permit(:name, :trigger_type, :trigger_days, :trigger_date, :active,
                       subject: {}, body: {})
      end

      def flow_json(flow)
        {
          id: flow.id, name: flow.name, subject: flow.subject, body: flow.body,
          trigger_type: flow.trigger_type, trigger_days: flow.trigger_days,
          trigger_date: flow.trigger_date, active: flow.active,
          total_sends: flow.email_flow_sends.count,
          total_opened: flow.email_flow_sends.where(status: 'opened').count
        }
      end
    end
  end
end
