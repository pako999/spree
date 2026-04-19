import { Controller } from "@hotwired/stimulus"

// Blocks the payment form submit until the T&C checkbox is checked.
// Disables the submit button and intercepts form submit as a safety net.
export default class extends Controller {
  static targets = ["checkbox", "error"]

  connect() {
    this.form = this.element.closest("form")
    this.updateButton()

    if (this.form) {
      this.boundSubmit = this.handleSubmit.bind(this)
      this.form.addEventListener("submit", this.boundSubmit)
    }
  }

  disconnect() {
    if (this.form && this.boundSubmit) {
      this.form.removeEventListener("submit", this.boundSubmit)
    }
  }

  toggle() {
    this.updateButton()
    if (this.hasErrorTarget) {
      this.errorTarget.classList.toggle("hidden", this.checkboxTarget.checked)
    }
  }

  handleSubmit(event) {
    if (!this.checkboxTarget.checked) {
      event.preventDefault()
      event.stopImmediatePropagation()
      if (this.hasErrorTarget) {
        this.errorTarget.classList.remove("hidden")
        this.errorTarget.scrollIntoView({ behavior: "smooth", block: "nearest" })
      }
    }
  }

  updateButton() {
    const btn = document.getElementById("checkout-payment-submit")
    if (!btn) return

    if (this.checkboxTarget.checked) {
      btn.disabled = false
      btn.classList.remove("opacity-40", "cursor-not-allowed")
    } else {
      btn.disabled = true
      btn.classList.add("opacity-40", "cursor-not-allowed")
    }
  }
}
