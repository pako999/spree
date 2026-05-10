import { Controller } from '@hotwired/stimulus'

/**
 * Toggle controller — collapses / expands a set of target elements by
 * adding or removing a configurable CSS class (defaults to "hidden").
 *
 * Usage in ERB:
 *   <div data-controller="toggle" data-toggle-class="hidden">
 *     <button data-action="click->toggle#toggle">Title</button>
 *     <div data-toggle-target="toggleable" class="hidden">Content</div>
 *   </div>
 *
 * Multiple toggleable targets are all toggled at once — useful for swapping
 * two chevron icons (one visible, one hidden) alongside the content area.
 */
export default class extends Controller {
  static classes = ['toggle']
  static targets = ['toggleable']

  toggle (event) {
    event.preventDefault()
    const cls = this.hasToggleClass ? this.toggleClass : 'hidden'
    this.toggleableTargets.forEach(el => el.classList.toggle(cls))
  }
}
