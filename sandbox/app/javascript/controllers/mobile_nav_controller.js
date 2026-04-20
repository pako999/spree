import { Controller } from '@hotwired/stimulus'

// Override of spree_storefront mobile_nav_controller.
// Bug: original uses e.target.querySelector('template') which fails when
// a child element (span, svg) is clicked because e.target is the span,
// not the button. e.currentTarget is always the element with data-action.
export default class extends Controller {
  static targets = ['submenuContainer']

  openSubmenu(e) {
    const template = e.currentTarget.querySelector('template')
    if (template) {
      this.submenuContainerTarget.innerHTML = template.innerHTML
      this.element.style.setProperty('--tw-translate-x', '-100vw')
    }
  }

  closeSubmenu() {
    this.element.style.setProperty('--tw-translate-x', null)
  }
}
