require "aws-sdk-s3"
require "marcel"

client = Aws::S3::Client.new(
  access_key_id: "ac7e3bbb7ccc50ddabb46b395fbac80e",
  secret_access_key: "24077a93b38c5e4cb6076ed7d8dcc1c1affa02ec78f6fd4d077d55ac73a1fba3",
  region: "auto",
  endpoint: "https://8b7e078431b06069d14ce4bd18839679.r2.cloudflarestorage.com"
)

BUCKET = "surf-store-storage"
local = ActiveStorage::Blob.service
storage_root = Rails.root.join("storage")

# Step 1: Download missing blob files from R2 to local disk
puts "=== Step 1: Download missing blob files from R2 ==="
db_keys = Set.new(ActiveStorage::Blob.pluck(:key))
downloaded = 0
already_local = 0
not_in_r2 = 0

db_keys.each_with_index do |key, idx|
  next if local.exist?(key)
  
  r2_key = "#{key[0..1]}/#{key[2..3]}/#{key}"
  begin
    resp = client.get_object(bucket: BUCKET, key: r2_key)
    data = resp.body.read
    local.upload(key, StringIO.new(data))
    downloaded += 1
  rescue Aws::S3::Errors::NotFound
    not_in_r2 += 1
  rescue => e
    not_in_r2 += 1
  end
  
  print "\r  Progress: #{idx+1}/#{db_keys.size} (downloaded: #{downloaded})..." if (idx+1) % 500 == 0
end

puts "\n  Downloaded from R2: #{downloaded}"
puts "  Not in R2: #{not_in_r2}"

# Step 2: Find orphaned local files and try to create blob records + match to products
puts "\n=== Step 2: Restore orphaned local files to DB ==="
disk_keys = Set.new
Dir.glob(File.join(storage_root, "**", "*")).each do |path|
  next if File.directory?(path)
  key = File.basename(path)
  next if key == ".keep"
  disk_keys.add(key)
end

current_db_keys = Set.new(ActiveStorage::Blob.pluck(:key))
orphaned = disk_keys - current_db_keys
puts "  Orphaned disk files: #{orphaned.size}"

# Create blob records for orphaned files
created_blobs = 0
orphaned.each do |key|
  path = File.join(storage_root, key[0..1], key[2..3], key)
  next unless File.exist?(path)
  
  data = File.read(path, mode: "rb")
  
  # Detect content type from magic bytes
  content_type = Marcel::MimeType.for(StringIO.new(data))
  next unless content_type&.start_with?("image/")
  
  checksum = Digest::MD5.base64digest(data)
  
  begin
    ActiveStorage::Blob.create!(
      key: key,
      filename: "recovered_#{key}.#{content_type.split('/').last}",
      content_type: content_type,
      byte_size: data.bytesize,
      checksum: checksum,
      service_name: "local",
      metadata: {}
    )
    created_blobs += 1
  rescue => e
    # skip duplicates
  end
end
puts "  Created blob records: #{created_blobs}"

# Step 3: Try to match recovered blobs to products without images
puts "\n=== Step 3: Match recovered blobs to products ==="
# Get products without master images
missing_products = Spree::Product.published
  .joins(:master)
  .left_joins(master: :images)
  .where(spree_assets: { id: nil })
  .includes(:master)
  .to_a

puts "  Products needing images: #{missing_products.size}"

# Get unattached image blobs (blobs that have no attachment)
unattached_blobs = ActiveStorage::Blob
  .left_joins(:attachments)
  .where(active_storage_attachments: { id: nil })
  .where("content_type LIKE 'image/%'")
  .where("byte_size > 10000")
  .order(created_at: :desc)
  .to_a

puts "  Unattached image blobs available: #{unattached_blobs.size}"

# We can't automatically match blobs to specific products without filenames
# But we can report what we have
puts "\n=== Summary ==="
working_images = 0
broken_images = 0
Spree::Image.includes(attachment_attachment: :blob).find_each do |img|
  b = img.attachment&.blob rescue nil
  next unless b
  if local.exist?(b.key)
    working_images += 1
  else
    broken_images += 1
  end
end

puts "Total images: #{Spree::Image.count}"
puts "Working (file on disk): #{working_images}"
puts "Broken (no file): #{broken_images}"
puts "Products without images: #{missing_products.size}"
puts "Unattached blobs: #{unattached_blobs.size}"
