# frozen_string_literal: true
# =============================================================================
# Fix ALL oversized product images store-wide
# - Resize any image > 1000px on either dimension to fit within 1000x1000
# - Pad to square with white background (so boards/kites show in full)
# - Convert to WebP for faster loading
#
# Run: RAILS_ENV=production bundle exec rails runner lib/tasks/fix_large_images_all_brands.rb
# =============================================================================

require 'vips'

MAX_SIZE    = 1000
WEBP_Q      = 80
LOG_FILE    = '/tmp/fix_large_images.log'

def log(msg)
  puts msg
  File.open(LOG_FILE, 'a') { |f| f.puts "[#{Time.now.strftime('%H:%M:%S')}] #{msg}" }
end

log "=== Fix Large Images — ALL Brands ==="
log "Target: max #{MAX_SIZE}x#{MAX_SIZE}px, square-padded, WebP"
log ""

# Find all product images where width OR height > 1000 (or still PNG/JPEG which we can convert)
# Focus on recently imported products (created 2026 or later) + Cabrinha/JP/Tabou
brand_permalinks = %w[
  brands/cabrinha
  brands/jp-australia
  brands/jp-australia-sup-windsurf-boards
  brands/tabou
  brands/neilpryde
  brands/gaastra
  brands/fanatic-sup
  brands/fanatic-windsurfing
  brands/fanatic-x
  brands/duotone-sup
  brands/duotone-kiteboarding
  brands/duotone-wing-foiling
  brands/duotone-windsurfing
  brands/duotone-foilwing
  brands/duotone-foiling-and-electric
  brands/nobile
]

brand_taxons = Spree::Taxon.where(permalink: brand_permalinks)
log "Checking #{brand_taxons.count} brand taxons"

products = Spree::Product
  .joins(:taxons)
  .where(taxons: { id: brand_taxons.ids })
  .distinct

log "Total products to check: #{products.count}"
log ""

processed = 0
skipped   = 0
errors    = 0
too_small = 0

products.each do |product|
  all_variants = [product.master] + product.variants.to_a
  images = Spree::Image.where(viewable: all_variants)
  next if images.empty?

  images.each_with_index do |img, idx|
    blob = img.attachment.blob
    meta = blob.metadata

    # Ensure analyzed
    unless blob.analyzed?
      blob.analyze rescue nil
      blob.reload
      meta = blob.metadata
    end

    w = meta['width'].to_i
    h = meta['height'].to_i
    ct = blob.content_type.to_s

    # Skip if already small WebP square
    if w <= MAX_SIZE && h <= MAX_SIZE && ct == 'image/webp' && w == h
      skipped += 1
      next
    end

    # Skip non-image blobs
    unless ct.start_with?('image/')
      skipped += 1
      next
    end

    # Skip tiny images (broken/placeholder)
    if w < 50 || h < 50
      too_small += 1
      next
    end

    # Only process if oversized OR not WebP OR not square
    needs_resize  = w > MAX_SIZE || h > MAX_SIZE
    needs_webp    = ct != 'image/webp'
    needs_square  = w != h

    unless needs_resize || needs_webp || needs_square
      skipped += 1
      next
    end

    begin
      raw_data = blob.download
      vips_img = Vips::Image.new_from_buffer(raw_data, '')
      raw_data = nil  # free memory early

      # Step 1: Resize to fit within MAX_SIZE x MAX_SIZE (preserve aspect ratio)
      iw = vips_img.width
      ih = vips_img.height
      if iw > MAX_SIZE || ih > MAX_SIZE
        scale    = [MAX_SIZE.to_f / iw, MAX_SIZE.to_f / ih].min
        vips_img = vips_img.resize(scale)
        iw = vips_img.width
        ih = vips_img.height
      end

      # Step 2: Pad to square with white background
      size = [iw, ih].max
      left = ((size - iw) / 2.0).round
      top  = ((size - ih) / 2.0).round

      # Handle images with alpha channel — flatten to white first
      if vips_img.has_alpha?
        vips_img = vips_img.flatten(background: [255, 255, 255])
      end

      padded = vips_img.embed(left, top, size, size,
                              extend: :white,
                              background: [255, 255, 255])

      # Step 3: Save as WebP
      tmp = Tempfile.new(['sq_img', '.webp'])
      padded.write_to_file(tmp.path, Q: WEBP_Q, strip: true)
      tmp.rewind

      orig_name = blob.filename.to_s.sub(/\.\w+$/, '.webp')
      img.attachment.attach(
        io: tmp,
        filename: orig_name,
        content_type: 'image/webp'
      )
      img.save!
      processed += 1

      action = [
        needs_resize  ? "resize #{w}x#{h}->#{size}x#{size}" : "pad #{iw}x#{ih}->#{size}x#{size}",
        needs_webp    ? "+webp" : nil,
      ].compact.join(' ')

      log "  OK #{product.name[0..35].ljust(36)} img#{idx+1}: #{action}"

      tmp.unlink rescue nil
      GC.compact if processed % 20 == 0

    rescue => e
      errors += 1
      log "  ERR #{product.name[0..35]} img#{idx+1}: #{e.message[0..100]}"
    end
  end
end

log ""
log "=== COMPLETE ==="
log "  Processed (resized/converted): #{processed}"
log "  Skipped (already OK):          #{skipped}"
log "  Too small (< 50px):            #{too_small}"
log "  Errors:                        #{errors}"
