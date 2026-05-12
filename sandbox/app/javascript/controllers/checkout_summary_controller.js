import { Controller } from '@hotwired/stimulus'

// Override of the Spree storefront checkout_summary_controller.
// Keeps the order summary always expanded (never adds summary-folded class).
export default class extends Controller {
  static targets = [
    'container',
    'content',
    'wrapper',
    'line_items',
    'coupon_area'
  ]

  onCouponResize() {
    if (this.hasLine_itemsTarget && this.hasCoupon_areaTarget) {
      this.line_itemsTarget.style.maxHeight = `${window.innerHeight - this.coupon_areaTarget.offsetHeight - 20}px`
    }
  }

  connect() {
    var summary = this.containerTarget
    var content = this.contentTarget

    // Always show summary — set height to content height and do NOT fold
    summary.style.height = content.offsetHeight + 'px'
    // Remove summary-folded if it was set (never fold)
    this.wrapperTarget.classList.remove('summary-folded')

    this.observer = new ResizeObserver(() => {
      summary.style.height = content.offsetHeight + 'px'
    })

    if (this.hasCoupon_areaTarget) {
      this.couponObserver = new ResizeObserver(this.onCouponResize.bind(this))
      this.couponObserver.observe(this.coupon_areaTarget)
    }

    window.addEventListener('resize', this.onCouponResize.bind(this))
    this.observer.observe(content)
  }

  disconnect() {
    if (this.observer) this.observer.disconnect()
    if (this.couponObserver) this.couponObserver.disconnect()
    window.removeEventListener('resize', this.onCouponResize.bind(this))
  }
}
