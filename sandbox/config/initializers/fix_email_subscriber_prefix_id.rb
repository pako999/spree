# Fix: event payload contains prefix_id (or_xxx) but email subscribers
# use find_by(id:) which expects integer DB id. This prepends prefix_id
# lookup to all 3 email subscribers.
Rails.application.config.to_prepare do
  Spree::OrderEmailSubscriber.class_eval do
    private

    def find_order(event)
      order_id = event.payload['id']
      Spree::Order.find_by(prefix_id: order_id) || Spree::Order.find_by(id: order_id)
    end
  end

  Spree::ShipmentEmailSubscriber.class_eval do
    private

    def find_shipment(event)
      shipment_id = event.payload['id']
      Spree::Shipment.find_by(prefix_id: shipment_id) || Spree::Shipment.find_by(id: shipment_id)
    end
  end

  Spree::ReimbursementEmailSubscriber.class_eval do
    private

    def find_reimbursement(event)
      reimbursement_id = event.payload['id']
      Spree::Reimbursement.find_by(prefix_id: reimbursement_id) || Spree::Reimbursement.find_by(id: reimbursement_id)
    end
  end
end
