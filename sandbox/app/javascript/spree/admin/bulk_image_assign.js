// Bulk "Assign Image" for selected variants
// Injected via admin layout — doesn't modify vendor gem JS
document.addEventListener('DOMContentLoaded', () => {
  // Wait for Stimulus to connect the variants-form controller
  const observer = new MutationObserver(() => {
    const btn = document.querySelector('[data-action="variants-form#assignImageToSelected"]')
    if (!btn || btn.dataset.bulkImageReady) return
    btn.dataset.bulkImageReady = 'true'

    btn.addEventListener('click', (e) => {
      e.preventDefault()
      e.stopPropagation()

      // Get the variants-form controller element
      const formEl = btn.closest('[data-controller*="variants-form"]')
      if (!formEl) return

      // Find checked variant checkboxes
      const checked = Array.from(formEl.querySelectorAll('input[data-variants-form-target="checkbox"]:checked'))
      if (checked.length === 0) return

      // Get variant IDs and targets
      const variantIdsJson = formEl.dataset.variantsFormVariantIdsValue
      const variantPrefixIdsJson = formEl.dataset.variantsFormVariantPrefixIdsValue
      const imagesJson = formEl.dataset.variantsFormAllProductImagesValue
      if (!variantIdsJson || !imagesJson) return

      const variantIds = JSON.parse(variantIdsJson)
      const variantPrefixIds = JSON.parse(variantPrefixIdsJson || '{}')
      const images = JSON.parse(imagesJson)

      if (images.length === 0) {
        alert('No product images available. Upload images first.')
        return
      }

      const selectedVariants = checked.map(cb => {
        const internalName = cb.value
        const row = formEl.querySelector(`[data-variant-name="${internalName}"]`)
        const variantId = variantIds[internalName]
        const prefixId = variantPrefixIds[internalName] || variantId
        return { internalName, row, variantId, prefixId }
      }).filter(v => v.variantId && v.row)

      if (selectedVariants.length === 0) return

      // Remove existing modal
      const existing = document.getElementById('bulk-image-picker-modal')
      if (existing) existing.remove()

      // Build modal
      const modal = document.createElement('div')
      modal.id = 'bulk-image-picker-modal'
      modal.style.cssText = 'position:fixed;top:0;left:0;width:100%;height:100%;background:rgba(0,0,0,0.5);z-index:9999;display:flex;align-items:center;justify-content:center;'
      modal.addEventListener('click', (e) => { if (e.target === modal) modal.remove() })

      const imagesHTML = images.map(img => `
        <div class="bulk-img-item" data-image-id="${img.id}"
             style="cursor:pointer;border:2px solid #e5e7eb;border-radius:8px;overflow:hidden;aspect-ratio:1;position:relative;transition:all 0.15s;">
          <img src="${img.url}" style="width:100%;height:100%;object-fit:cover;" loading="lazy" />
        </div>
      `).join('')

      modal.innerHTML = `
        <div style="background:white;border-radius:12px;max-width:600px;width:90%;max-height:80vh;display:flex;flex-direction:column;box-shadow:0 20px 60px rgba(0,0,0,0.3);">
          <div style="padding:16px 20px;border-bottom:1px solid #e5e7eb;display:flex;justify-content:space-between;align-items:center;">
            <div>
              <h3 style="margin:0;font-size:16px;font-weight:600;">Assign image to ${selectedVariants.length} variant${selectedVariants.length > 1 ? 's' : ''}</h3>
              <p style="margin:4px 0 0;font-size:13px;color:#6b7280;">Click an image to assign it to all selected variants</p>
            </div>
            <button id="bulk-img-close" style="background:none;border:none;font-size:24px;cursor:pointer;color:#9ca3af;padding:4px 8px;line-height:1;">&times;</button>
          </div>
          <div style="padding:16px 20px;overflow-y:auto;flex:1;">
            <div style="display:grid;grid-template-columns:repeat(3,1fr);gap:12px;">
              ${imagesHTML}
            </div>
          </div>
        </div>
      `
      document.body.appendChild(modal)

      // Hover effects
      modal.querySelectorAll('.bulk-img-item').forEach(item => {
        item.addEventListener('mouseenter', () => { item.style.borderColor = '#3b82f6'; item.style.transform = 'scale(1.03)' })
        item.addEventListener('mouseleave', () => { item.style.borderColor = '#e5e7eb'; item.style.transform = 'scale(1)' })
      })

      // Close
      modal.querySelector('#bulk-img-close').addEventListener('click', () => modal.remove())
      document.addEventListener('keydown', function esc(e) { if (e.key === 'Escape') { modal.remove(); document.removeEventListener('keydown', esc) } })

      // Image click — assign to all selected
      modal.querySelectorAll('.bulk-img-item').forEach(item => {
        item.addEventListener('click', async () => {
          const imageId = item.dataset.imageId
          item.style.opacity = '0.5'
          item.style.pointerEvents = 'none'

          const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
          const pathMatch = window.location.pathname.match(/^(\/[^/]+)\/products\/([^/]+)/)
          if (!pathMatch) { alert('Could not determine product path.'); return }

          const adminPath = pathMatch[1]
          const productSlug = pathMatch[2]
          let ok = 0

          for (const v of selectedVariants) {
            try {
              const res = await fetch(`${adminPath}/products/${productSlug}/variants/${v.prefixId}/assign_image`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json', 'Accept': 'application/json', 'X-CSRF-Token': csrfToken },
                body: JSON.stringify({ image_id: imageId })
              })
              if (res.ok) {
                // Update thumbnail
                const img = v.row.querySelector('[data-slot="variantImage"]')
                const ph = v.row.querySelector('[data-slot="variantImagePlaceholder"]')
                const src = item.querySelector('img')?.src
                if (img && src) { img.src = src; img.classList.remove('hidden'); if (ph) ph.classList.add('hidden') }
                ok++
              }
            } catch (err) {
              console.error('Assign image failed:', v.internalName, err)
            }
          }

          modal.remove()
          if (ok < selectedVariants.length) alert(`Assigned to ${ok}/${selectedVariants.length} variants.`)
        })
      })
    })
  })

  observer.observe(document.body, { childList: true, subtree: true })
  // Also run immediately
  setTimeout(() => observer.disconnect(), 10000)
})
