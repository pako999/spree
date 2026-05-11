import { Controller } from "@hotwired/stimulus"

const fmt = (n) =>
  new Intl.NumberFormat('de-DE', { style: 'currency', currency: 'EUR' }).format(n)

export default class extends Controller {
  static values = { productId: String }

  connect() {
    const script = document.getElementById(`variant-data-${this.productIdValue}`)
    this.variants = script ? JSON.parse(script.textContent) : []
    this.form = this.element.closest('form')
    this.container = this.element.closest('[data-controller~="product-form"]')
  }

  switch(event) {
    const variant = this.findVariant()
    if (!variant) return

    // 1. Update variant_id hidden field for cart
    const variantInput = this.form?.querySelector('input[name="variant_id"]')
    if (variantInput) variantInput.value = variant.id

    // 2. Instantly replace price HTML
    const priceRow = this.container?.querySelector('.pdp-price-row')
    if (priceRow) priceRow.innerHTML = this.buildPrice(variant)

    // 3. Toggle Add to Cart button
    const btn = this.form?.querySelector('[data-product-form-target="submit"]')
    if (btn) btn.disabled = !variant.available

    // 4. Update color label text (desktop)
    if (variant.color) {
      const colorLabel = this.container?.querySelector('[data-option-id] span')
      if (colorLabel) colorLabel.textContent = `COLOR: ${variant.color}`
    }
  }

  findVariant() {
    const selected = {}
    // Collect from both desktop and mobile hidden radios
    this.element.querySelectorAll('input[type="radio"]').forEach(r => {
      if (r.checked && r.dataset.optionId) selected[r.dataset.optionId] = r.value
    })
    if (!Object.keys(selected).length) return null
    return this.variants.find(v =>
      Object.entries(v.option_ids).every(([id, val]) => selected[id] === val)
    )
  }

  buildPrice(v) {
    const onSale = v.on_sale && v.compare_at && v.compare_at > v.price
    if (onSale) {
      const pct = Math.round((1 - v.price / v.compare_at) * 100)
      return `
        <span class="pdp-price-current">${fmt(v.price)}</span>
        <span style="font-size:.75rem;color:#6b7280;">VAT Included</span>
        <span class="pdp-price-divider">|</span>
        <span class="pdp-price-original">Originally ${fmt(v.compare_at)}</span>
        <span class="pdp-price-divider">|</span>
        <span class="pdp-discount-badge">-${pct}%</span>`
    }
    return `
      <span class="pdp-price-current regular">${fmt(v.price)}</span>
      <span style="font-size:.75rem;color:#6b7280;">VAT Included</span>`
  }
}
