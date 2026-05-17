#!/usr/bin/env ruby
# frozen_string_literal: true
# Purge image assets whose physical file doesn't exist on disk.
# Safe: only removes DB records for files that are truly gone.
# Run: bundle exec rails runner /rails/tmp/purge_missing_images.rb

puts "=== Purging orphaned image assets (file missing from disk) ==="

storage_root = Rails.root.join("storage")
checked = 0
deleted = 0

ActiveStorage::Blob
  .joins("JOIN active_storage_attachments aa ON aa.blob_id = active_storage_blobs.id")
  .joins("JOIN spree_assets sa ON sa.id = aa.record_id AND aa.record_type = 'Spree::Asset'")
  .where("sa.type = 'Spree::Image'")
  .find_each(batch_size: 200) do |blob|
    checked += 1

    key  = blob.key
    path = storage_root.join(key[0, 2], key[2, 2], key)

    next if File.exist?(path)

    # File is missing — remove DB records
    asset_ids = ActiveStorage::Attachment
      .where(blob_id: blob.id, record_type: "Spree::Asset")
      .pluck(:record_id)

    ActiveStorage::VariantRecord.where(blob_id: blob.id).delete_all
    ActiveStorage::Attachment.where(blob_id: blob.id).delete_all
    Spree::Image.where(id: asset_ids).delete_all
    blob.delete

    deleted += 1
    print "." if (deleted % 100).zero?
  end

puts "\n"
puts "Checked: #{checked}"
puts "Deleted orphans: #{deleted}"
puts "Remaining: #{checked - deleted}"
puts "Done: #{Time.current}"
