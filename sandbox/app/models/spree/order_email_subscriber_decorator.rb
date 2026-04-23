# Fix: event payload contains prefix_id (or_xxx) but the original
# find_order uses find_by(id:) which expects integer DB id.
# This decorator patches all 3 email subscribers to handle prefix_id.
module Spree
  module OrderEmailSubscriberPrefixIdFix
    private

    def find_order(event)
      order_id = event.payload['id']
      Spree::Order.find_by(prefix_id: order_id) || Spree::Order.find_by(id: order_id)
    end
  end

  module ShipmentEmailSubscriberPrefixIdFix
    private

    def find_shipment(event)
      shipment_id = event.payload['id']
      Spree::Shipment.find_by(prefix_id: shipment_id) || Spree::Shipment.find_by(id: shipment_id)
    end
  end

  module ReimbursementEmailSubscriberPrefixIdFix
    private

    def find_reimbursement(event)
      reimbursement_id = event.payload['id']
      Spree::Reimbursement.find_by(prefix_id: reimbursement_id) || Spree::Reimbursement.find_by(id: reimbursement_id)
    end
  end
end

Spree::OrderEmailSubscriber.prepend(Spree::OrderEmailSubscriberPrefixIdFix)
Spree::ShipmentEmailSubscriber.prepend(Spree::ShipmentEmailSubscriberPrefixIdFix)
Spree::ReimbursementEmailSubscriber.prepend(Spree::ReimbursementEmailSubscriberPrefixIdFix)
