# frozen_string_literal: true

# ── ar_lazy_preload ────────────────────────────────────────────────────────
# Enable automatic lazy preloading of ActiveRecord associations.
# Without this, Spree product listing pages fire 1,500+ queries per request.
# With auto_preload enabled, related associations are batched automatically,
# dropping query count to ~50-100 per page.
ArLazyPreload.config.auto_preload = true
