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

// When a page is served from Cloudflare cache, the session cookie is absent and
// the embedded CSRF token belongs to a stale session. Fetch a fresh token so
// add-to-cart / wishlist / form submissions don't fail with 422 Unprocessable.
async function refreshCsrfIfCached() {
  const hasSession = document.cookie.split(';').some(c => c.trim().startsWith('_sandbox_session='))
  if (hasSession) return
  try {
    const r = await fetch('/csrf_token', { headers: { Accept: 'application/json' } })
    if (!r.ok) return
    const { token } = await r.json()
    // Update the live meta tag
    const meta = document.head.querySelector('meta[name="csrf-token"]')
    if (meta) meta.setAttribute('content', token)
    // Also update the template so injectCsrfMetaTags stays in sync
    const tpl = document.getElementById('csrf_meta_tags')
    const tplMeta = tpl?.content?.querySelector('meta[name="csrf-token"]')
    if (tplMeta) tplMeta.setAttribute('content', token)
  } catch (_) {}
}

document.addEventListener('DOMContentLoaded', refreshCsrfIfCached)
document.addEventListener('turbo:load', refreshCsrfIfCached)

// Mark the active nav item based on the current URL.
// The header is now cached without request.path (one cache entry for all pages),
// so the active state can't be set server-side — we set it here instead.
function setActiveNavItem() {
  const path = window.location.pathname
  document.querySelectorAll('.header--nav-link[href]').forEach(link => {
    const href = link.getAttribute('href')
    if (!href || href === '#') return
    const homeOnly = link.dataset.navHome === 'true'
    const isActive = homeOnly ? path === href : (href !== '/' && path.startsWith(href))
    link.classList.toggle('menu-item--active', isActive)
  })
}
document.addEventListener('DOMContentLoaded', setActiveNavItem)
document.addEventListener('turbo:load', setActiveNavItem)
