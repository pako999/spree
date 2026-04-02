// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// Inject fresh CSRF meta tags from <template id="csrf_meta_tags"> into <head>
// so that @rails/request.js can find them via document.head.querySelector.
// The template lives outside <html> to avoid page-cache poisoning.
function injectCsrfMetaTags() {
  const tpl = document.getElementById('csrf_meta_tags')
  if (!tpl) return
  ;['csrf-token', 'csrf-param'].forEach(name => {
    const existing = document.head.querySelector(`meta[name="${name}"]`)
    const fresh = tpl.content.querySelector(`meta[name="${name}"]`)
    if (!fresh) return
    if (existing) {
      existing.setAttribute('content', fresh.getAttribute('content'))
    } else {
      document.head.appendChild(fresh.cloneNode(true))
    }
  })
}

document.addEventListener('DOMContentLoaded', injectCsrfMetaTags)
document.addEventListener('turbo:load', injectCsrfMetaTags)
document.addEventListener('turbo:frame-load', injectCsrfMetaTags)
