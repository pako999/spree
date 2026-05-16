class EmailFlow < ApplicationRecord
  has_many :email_flow_sends, dependent: :destroy

  validates :name, presence: true
  validates :trigger_type, presence: true, inclusion: { in: %w[days_after_pickup specific_date manual] }
  validates :trigger_days, presence: true, if: -> { trigger_type == 'days_after_pickup' }
  validates :trigger_date, presence: true, if: -> { trigger_type == 'specific_date' }
  validate :subject_has_default_language
  validate :body_has_default_language

  scope :active, -> { where(active: true) }
  scope :automated, -> { where(trigger_type: %w[days_after_pickup specific_date]) }

  def subject_for(language)
    subject[language] || subject['en'] || subject.values.first
  end

  def body_for(language)
    body[language] || body['en'] || body.values.first
  end

  def render_body(language, customer:, order: nil)
    template = body_for(language)
    last_order = order || customer.last_stringing_order

    template
      .gsub('{name}', customer.full_name)
      .gsub('{first_name}', customer.first_name)
      .gsub('{last_stringing_date}', last_order&.picked_up_at&.strftime('%d.%m.%Y') || '-')
      .gsub('{racket_model}', last_order ? "#{last_order.racket_brand} #{last_order.racket_model}" : '-')
      .gsub('{days_since_stringing}', (customer.days_since_last_stringing || 0).to_s)
  end

  def render_subject(language, customer:)
    template = subject_for(language)
    template
      .gsub('{name}', customer.full_name)
      .gsub('{first_name}', customer.first_name)
  end

  def customers_due
    case trigger_type
    when 'days_after_pickup'
      StringingCustomer.subscribed.joins(:stringing_orders)
        .where(stringing_orders: { status: 'picked_up' })
        .where('stringing_orders.picked_up_at <= ?', trigger_days.days.ago)
        .where.not(id: email_flow_sends.select(:stringing_customer_id))
        .distinct
    when 'specific_date'
      return StringingCustomer.none unless trigger_date == Date.current
      StringingCustomer.subscribed
        .where.not(id: email_flow_sends.select(:stringing_customer_id))
    else
      StringingCustomer.none
    end
  end

  private

  def subject_has_default_language
    errors.add(:subject, 'must have at least an English version') if subject.blank? || subject['en'].blank?
  end

  def body_has_default_language
    errors.add(:body, 'must have at least an English version') if body.blank? || body['en'].blank?
  end
end
