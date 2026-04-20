import { Controller } from '@hotwired/stimulus'

// Override of spree_storefront mobile_nav_controller.
//
// Fixes two iOS Safari bugs:
//  1. e.target vs e.currentTarget — original failed when a child span/svg
//     was tapped because e.target is the span, not the button.
//     e.currentTarget is always the element that owns the data-action.
//  2. <template> inside <button> — iOS Safari's parser may hoist the
//     template node outside the button, so querySelector('template')
//     (which only searches descendants) returns null. The template is
//     now placed as the button's nextElementSibling in the HTML, so we
//     reach it without any DOM-tree ambiguity.
//  3. template.innerHTML is unreliable on iOS; use template.content with
//     cloneNode(true) instead.
export default class extends Controller {
  static targets = ['submenuContainer']

  openSubmenu(e) {
    const template = e.currentTarget.nextElementSibling
    if (!template || template.tagName !== 'TEMPLATE') return
    this.submenuContainerTarget.innerHTML = ''
    this.submenuContainerTarget.appendChild(template.content.cloneNode(true))
    this.element.style.setProperty('--tw-translate-x', '-100vw')
  }

  closeSubmenu() {
    this.element.style.setProperty('--tw-translate-x', null)
  }
}
