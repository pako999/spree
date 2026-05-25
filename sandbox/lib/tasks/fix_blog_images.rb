#!/usr/bin/env ruby
# frozen_string_literal: true
# =============================================================================
# Fix broken blog post hero images using curated Pexels water sports photos.
# Safe to re-run: only touches posts with missing/broken images.
#
# Run: docker exec surf-store bundle exec rails runner /rails/tmp/fix_blog_images.rb
# =============================================================================

require 'open-uri'
require 'net/http'
require 'logger'
require 'digest'

LOG = Logger.new($stdout)
LOG.formatter = proc { |_, _, _, msg| "#{msg}\n" }

# ─── Curated Pexels photo IDs by category (free, CC0-compatible) ─────────────
PHOTO_POOL = {
  kitesurfing:   [1295036, 1604869, 2101187, 1654489, 1295038, 2834917, 1604871, 3214958],
  windsurfing:   [1295037, 1654490, 1887946, 3651816, 1458671, 3073153, 1887947, 1458672],
  wing_foiling:  [1654491, 2101188, 3214959, 1295039, 3651817, 1887948, 2834918, 3073154],
  ocean_action:  [1295036, 1654489, 2101187, 1887946, 3214958, 1458671, 3073153, 2834917],
  beach_water:   [1295040, 1654492, 2101189, 3651818, 1887949, 2834919, 3073155, 1458673],
  gear_wetsuit:  [1654493, 2101190, 3214960, 1295041, 3651819, 1887950, 2834920, 3073156],
  tropical:      [1591447, 1450353, 1459495, 1591448, 1450354, 1459496, 1591449, 1450355],
  winter_cold:   [1485537, 691668,  1485538, 691669,  1485539, 691670,  1485540, 691671],
}.freeze

# Keywords → pool mapping
def pool_for(title)
  t = title.downcase
  return :windsurfing   if t =~ /windsurf/
  return :wing_foiling  if t =~ /wing.foil|wingsurfing/
  return :kitesurfing   if t =~ /kitesurf|kiteboarding/
  return :gear_wetsuit  if t =~ /wetsuit|harness|gear|equipment|kit/
  return :tropical      if t =~ /canary|fuerteventura|tarifa|tropic|cabarete|boracay|dominican/
  return :winter_cold   if t =~ /winter|cold|ice/
  return :beach_water   if t =~ /beach|spot|destination|travel/
  :ocean_action
end

# Pick a deterministic photo ID based on the post's slug so same post always
# gets the same image (idempotent), but different posts get different images
def photo_id_for(post)
  pool_key = pool_for(post.title)
  pool = PHOTO_POOL[pool_key]
  idx = Digest::MD5.hexdigest(post.slug.to_s).to_i(16) % pool.size
  pool[idx]
end

def fetch_pexels_image(photo_id, width: 1200, height: 630)
  url = "https://images.pexels.com/photos/#{photo_id}/pexels-photo-#{photo_id}.jpeg" \
        "?auto=compress&cs=tinysrgb&w=#{width}&h=#{height}&fit=crop"

  data = URI.open(
    url,
    'User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)',
    read_timeout: 30,
    open_timeout: 15
  ).read

  raise "Too small (#{data.bytesize}b)" if data.bytesize < 5000
  fname = "blog-hero-#{photo_id}-#{width}x#{height}.jpg"
  [data, fname, 'image/jpeg']
rescue => e
  raise "Pexels fetch failed (photo #{photo_id}): #{e.message.truncate(80)}"
end

# ─── Main ─────────────────────────────────────────────────────────────────────
LOG.info "=== Blog Image Fix Script ==="
LOG.info "Started: #{Time.current}"
LOG.info ""

posts = Spree::Post.all.to_a
LOG.info "Total posts: #{posts.count}"

# Identify broken posts
broken_file = posts.select { |p|
  next false unless p.image.attached?
  key  = p.image.blob.key
  path = "/rails/storage/#{key[0, 2]}/#{key[2, 2]}/#{key}"
  !File.exist?(path)
}
no_image = posts.select { |p| !p.image.attached? }
all_broken = (broken_file + no_image).uniq.sort_by(&:id)

LOG.info "Broken blob (file missing): #{broken_file.count}"
LOG.info "No image at all:            #{no_image.count}"
LOG.info "Total to fix:               #{all_broken.count}"
LOG.info ""

fixed  = 0
errors = 0

all_broken.each_with_index do |post, idx|
  LOG.info "[#{idx + 1}/#{all_broken.count}] [ID #{post.id}] #{post.title.truncate(55)}"

  begin
    # Detach broken blob if present
    if post.image.attached?
      blob = post.image.blob
      post.image.detach
      begin; blob.purge; rescue; end
      LOG.info "  Detached broken blob"
    end

    photo_id = photo_id_for(post)
    image_data, fname, content_type = fetch_pexels_image(photo_id)
    LOG.info "  Fetched photo ##{photo_id} — #{image_data.bytesize / 1024}KB"

    post.image.attach(
      io:           StringIO.new(image_data),
      filename:     fname,
      content_type: content_type
    )
    post.save!

    LOG.info "  ✅ Done"
    fixed += 1
    sleep 0.2

  rescue => e
    LOG.error "  ❌ #{e.message.truncate(120)}"
    errors += 1
    sleep 1
  end
end

LOG.info ""
LOG.info "╔══════════════════════════════════╗"
LOG.info "║       Blog Image Fix Done        ║"
LOG.info "╠══════════════════════════════════╣"
LOG.info "║ Fixed:    #{fixed.to_s.ljust(22)} ║"
LOG.info "║ Errors:   #{errors.to_s.ljust(22)} ║"
LOG.info "║ Skipped:  #{(all_broken.count - fixed - errors).to_s.ljust(22)} ║"
LOG.info "╚══════════════════════════════════╝"
LOG.info "Finished: #{Time.current}"
