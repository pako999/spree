# Fix: non-EU customers should NOT pay EU VAT.
# Spree's default behavior falls back to the default_tax zone (SI VAT 22%)
# when no zone matches the customer's address. This causes non-EU customers
# to be charged VAT. Override to only fall back to default_tax if the
# customer's country is actually in the EU zone.
Rails.application.config.to_prepare do
  Spree::Order.class_eval do
    def tax_zone
      @tax_zone ||= begin
        matched = Spree::Zone.match(tax_address)
        if matched
          matched
        elsif tax_address&.country && eu_zone&.include?(tax_address)
          Spree::Zone.default_tax
        else
          nil # Non-EU → no VAT
        end
      end
    end

    private

    def eu_zone
      @eu_zone ||= Spree::Zone.find_by(name: 'EU')
    end
  end
end
