# frozen_string_literal: true
# Download blobs stored in R2 (cloudflare service) to local disk.
# Needed because service was accidentally set to :cloudflare during initial ION import.
# Run: bin/kamal app exec --reuse "bin/rails runner /rails/script/migrate_r2_to_local.rb"

require 'aws-sdk-s3'

BUCKET = 'surf-store-storage'

# Build S3 client using env vars (same as storage.yml)
s3 = Aws::S3::Client.new(
  access_key_id:     ENV['R2_ACCESS_KEY_ID'],
  secret_access_key: ENV['R2_SECRET_ACCESS_KEY'],
  region:            'auto',
  endpoint:          'https://8b7e078431b06069d14ce4bd18839679.r2.cloudflarestorage.com',
  force_path_style:  true,
  request_checksum_calculation: 'when_required',
  response_checksum_validation: 'when_required'
)

puts "Finding cloudflare blobs..."
cloudflare_blobs = ActiveStorage::Blob.where(service_name: 'cloudflare')
puts "Total cloudflare blobs: #{cloudflare_blobs.count}"

local_service = ActiveStorage::Blob.services.fetch(:local)
storage_root  = local_service.root

migrated = 0
skipped  = 0
errors   = 0

cloudflare_blobs.find_each do |blob|
  key        = blob.key
  local_path = File.join(storage_root, key[0..1], key[2..3], key)

  if File.exist?(local_path)
    skipped += 1
    next
  end

  begin
    FileUtils.mkdir_p(File.dirname(local_path))
    resp = s3.get_object(bucket: BUCKET, key: key)
    File.binwrite(local_path, resp.body.read)
    blob.update_columns(service_name: 'local')
    migrated += 1
    print "." if (migrated % 50).zero?
  rescue Aws::S3::Errors::NoSuchKey => e
    # File not in R2 either — blob is orphaned, delete it
    puts "\n  [orphan] #{key} — not in R2, deleting blob record"
    ActiveStorage::Attachment.where(blob_id: blob.id).destroy_all
    blob.destroy
    errors += 1
  rescue => e
    puts "\n  [error] #{key}: #{e.message.truncate(80)}"
    errors += 1
  end
end

puts "\n\n#{'='*50}"
puts "Migrated : #{migrated}"
puts "Skipped  : #{skipped} (already on disk)"
puts "Errors   : #{errors}"
puts "Remaining cloudflare: #{ActiveStorage::Blob.where(service_name: 'cloudflare').count}"
